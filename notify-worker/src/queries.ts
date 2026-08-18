/**
 * PostgREST Queries
 *
 * Fetches data from PostgREST using the SERVICE_ROLE_KEY to bypass RLS.
 * Works against both the self-hosted PostgREST container and Supabase Cloud's
 * REST endpoint (they use the same API surface).
 */

import { POSTGREST_URL, SERVICE_ROLE_KEY } from './index.js';

// =============================================================================
// Types
// =============================================================================

export interface Subscription {
    recordID: string;
    userID: string;
    endpoint: string;
    keyP256dh: string;
    keyAuth: string;
}

export interface Task {
    recordID: string;
    title: string;
    dueDate: number;
    status: string;
}

export interface Transaction {
    recordID: string;
    title: string;
    amount: number;
    transactionDate: number;
    transactionType: string;
}

// =============================================================================
// Fetch helpers
// =============================================================================

async function postgrestGet<T>(path: string): Promise<T[]> {
    const url = `${POSTGREST_URL}${path}`;
    const response = await fetch(url, {
        method: 'GET',
        headers: {
            'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
            'apikey': SERVICE_ROLE_KEY,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        },
    });

    if (!response.ok) {
        const body = await response.text();
        throw new Error(`PostgREST request failed: ${response.status} ${response.statusText} — ${body}`);
    }

    return response.json() as Promise<T[]>;
}

async function postgrestDelete(path: string): Promise<void> {
    const url = `${POSTGREST_URL}${path}`;
    const response = await fetch(url, {
        method: 'DELETE',
        headers: {
            'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
            'apikey': SERVICE_ROLE_KEY,
            'Content-Type': 'application/json',
        },
    });

    if (!response.ok) {
        const body = await response.text();
        console.error(`[queries] DELETE failed: ${response.status} — ${body}`);
    }
}

// =============================================================================
// Helpers
// =============================================================================

function getTodayString(): string {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

// =============================================================================
// Public API
// =============================================================================

/**
 * Fetch all push subscriptions for a given app.
 * Only returns subscriptions that haven't been notified today.
 */
export async function fetchSubscriptions(app: string): Promise<Subscription[]> {
    const today = getTodayString();
    return postgrestGet<Subscription>(
        `/push_subscriptions?app=eq.${app}&or=(lastNotifiedDate.is.null,lastNotifiedDate.neq.${today})&select=recordID,userID,endpoint,keyP256dh,keyAuth`
    );
}

/**
 * Remove an expired/revoked subscription by recordID.
 */
export async function removeSubscription(recordID: string): Promise<void> {
    return postgrestDelete(`/push_subscriptions?recordID=eq.${recordID}`);
}

/**
 * Mark a subscription as notified today so it won't be sent again until tomorrow.
 */
export async function markNotified(recordID: string): Promise<void> {
    const today = getTodayString();
    const url = `${POSTGREST_URL}/push_subscriptions?recordID=eq.${recordID}`;
    const response = await fetch(url, {
        method: 'PATCH',
        headers: {
            'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
            'apikey': SERVICE_ROLE_KEY,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
        },
        body: JSON.stringify({ lastNotifiedDate: today }),
    });

    if (!response.ok) {
        const body = await response.text();
        console.error(`[queries] PATCH markNotified failed: ${response.status} — ${body}`);
    }
}

/**
 * Fetch tasks that are due today or overdue for a given user.
 * Only returns open tasks with a non-null dueDate.
 */
export async function fetchTasksDue(userID: string): Promise<{ dueToday: Task[]; overdue: Task[] }> {
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const todayEnd = todayStart + 24 * 60 * 60 * 1000 - 1;

    // Fetch all open tasks with a due date for this user
    const tasks = await postgrestGet<Task>(
        `/tasks?creatorID=eq.${userID}&status=eq.open&dueDate=not.is.null&select=recordID,title,dueDate,status`
    );

    const dueToday: Task[] = [];
    const overdue: Task[] = [];

    for (const task of tasks) {
        if (task.dueDate < todayStart) {
            overdue.push(task);
        } else if (task.dueDate <= todayEnd) {
            dueToday.push(task);
        }
    }

    return { dueToday, overdue };
}

/**
 * Fetch transactions scheduled for tomorrow for a given user.
 * Looks at all budgets the user owns or has access to.
 */
export async function fetchTransactionsDue(userID: string): Promise<Transaction[]> {
    const now = new Date();
    const tomorrowStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1).getTime();
    const tomorrowEnd = tomorrowStart + 24 * 60 * 60 * 1000 - 1;

    // Fetch transactions owned by this user in tomorrow's range
    const transactions = await postgrestGet<Transaction>(
        `/transactions?creatorID=eq.${userID}&transactionDate=gte.${tomorrowStart}&transactionDate=lte.${tomorrowEnd}&select=recordID,title,amount,transactionDate,transactionType`
    );

    return transactions;
}
