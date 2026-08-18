/**
 * SimpleSuite Push Notification Worker
 *
 * Runs on a schedule (default: every 15 minutes) and sends Web Push
 * notifications for:
 *   - simpleTracker: tasks due today or overdue
 *   - simpleBudget: transactions scheduled for tomorrow
 *
 * Connects to PostgREST using the SERVICE_ROLE_KEY (bypasses RLS)
 * to query all users' data, then delivers push notifications to
 * subscribed devices via the web-push library.
 *
 * Works identically for self-hosted (Docker) and Supabase Cloud deployments.
 */

import webpush from 'web-push';
import { fetchSubscriptions, fetchTasksDue, fetchTransactionsDue, removeSubscription } from './queries.js';
import { buildTrackerPayload, buildBudgetPayload } from './payloads.js';

// =============================================================================
// Configuration
// =============================================================================

const VAPID_PUBLIC_KEY = requiredEnv('VAPID_PUBLIC_KEY');
const VAPID_PRIVATE_KEY = requiredEnv('VAPID_PRIVATE_KEY');
const VAPID_SUBJECT = process.env.VAPID_SUBJECT || 'mailto:admin@simplesuite.dev';
const CHECK_INTERVAL_MS = parseInt(process.env.CHECK_INTERVAL_MS || '900000', 10); // 15 min

// PostgREST connection (used by queries.ts)
export const POSTGREST_URL = requiredEnv('POSTGREST_URL'); // e.g. http://postgrest:3000 or https://xyz.supabase.co/rest/v1
export const SERVICE_ROLE_KEY = requiredEnv('SERVICE_ROLE_KEY');

function requiredEnv(name: string): string {
    const value = process.env[name];
    if (!value) {
        console.error(`[notify-worker] Missing required env var: ${name}`);
        process.exit(1);
    }
    return value;
}

// =============================================================================
// Setup
// =============================================================================

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

// =============================================================================
// Main loop
// =============================================================================

async function runCheck(): Promise<void> {
    const startTime = Date.now();
    console.log(`[notify-worker] Starting check at ${new Date().toISOString()}`);

    let sent = 0;
    let failed = 0;
    let removed = 0;

    try {
        // --- simpleTracker: tasks due today or overdue ---
        const trackerSubs = await fetchSubscriptions('simpletracker');
        if (trackerSubs.length > 0) {
            // Group subscriptions by user
            const trackerByUser = groupByUser(trackerSubs);

            for (const [userID, subs] of trackerByUser) {
                const tasks = await fetchTasksDue(userID);
                if (tasks.dueToday.length === 0 && tasks.overdue.length === 0) continue;

                const payload = buildTrackerPayload(tasks.dueToday, tasks.overdue);

                for (const sub of subs) {
                    const result = await sendPush(sub, payload);
                    if (result === 'sent') sent++;
                    else if (result === 'removed') { removed++; }
                    else failed++;
                }
            }
        }

        // --- simpleBudget: transactions due tomorrow ---
        const budgetSubs = await fetchSubscriptions('simplebudget');
        if (budgetSubs.length > 0) {
            const budgetByUser = groupByUser(budgetSubs);

            for (const [userID, subs] of budgetByUser) {
                const transactions = await fetchTransactionsDue(userID);
                if (transactions.length === 0) continue;

                const payload = buildBudgetPayload(transactions);

                for (const sub of subs) {
                    const result = await sendPush(sub, payload);
                    if (result === 'sent') sent++;
                    else if (result === 'removed') { removed++; }
                    else failed++;
                }
            }
        }
    } catch (err) {
        console.error('[notify-worker] Unexpected error during check:', err);
    }

    const elapsed = Date.now() - startTime;
    console.log(`[notify-worker] Check complete in ${elapsed}ms — sent: ${sent}, failed: ${failed}, expired removed: ${removed}`);
}

// =============================================================================
// Push delivery
// =============================================================================

interface Subscription {
    recordID: string;
    userID: string;
    endpoint: string;
    keyP256dh: string;
    keyAuth: string;
}

type SendResult = 'sent' | 'failed' | 'removed';

async function sendPush(sub: Subscription, payload: string): Promise<SendResult> {
    const pushSubscription: webpush.PushSubscription = {
        endpoint: sub.endpoint,
        keys: {
            p256dh: sub.keyP256dh,
            auth: sub.keyAuth,
        },
    };

    try {
        await webpush.sendNotification(pushSubscription, payload);
        return 'sent';
    } catch (err: any) {
        // 404 or 410 means the subscription expired or was revoked
        if (err.statusCode === 404 || err.statusCode === 410) {
            console.log(`[notify-worker] Subscription expired (${err.statusCode}), removing: ${sub.recordID}`);
            await removeSubscription(sub.recordID);
            return 'removed';
        }
        console.error(`[notify-worker] Failed to send to ${sub.endpoint}:`, err.statusCode || err.message);
        return 'failed';
    }
}

// =============================================================================
// Helpers
// =============================================================================

function groupByUser(subs: Subscription[]): Map<string, Subscription[]> {
    const map = new Map<string, Subscription[]>();
    for (const sub of subs) {
        const existing = map.get(sub.userID);
        if (existing) {
            existing.push(sub);
        } else {
            map.set(sub.userID, [sub]);
        }
    }
    return map;
}

// =============================================================================
// Scheduler
// =============================================================================

console.log(`[notify-worker] Starting with check interval: ${CHECK_INTERVAL_MS / 1000}s`);
console.log(`[notify-worker] PostgREST URL: ${POSTGREST_URL}`);

// Run immediately on startup, then on interval
runCheck();
setInterval(runCheck, CHECK_INTERVAL_MS);
