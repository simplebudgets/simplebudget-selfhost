/**
 * Push Notification Payload Builders
 *
 * Constructs the JSON payloads that get sent to the Service Worker's
 * push event handler. Matches the PushPayload interface defined in
 * each app's sw.ts.
 */

import type { Task, Transaction } from './queries.js';

interface PushPayload {
    title: string;
    body: string;
    icon: string;
    tag: string;
    data?: { url?: string };
}

// =============================================================================
// simpleTracker
// =============================================================================

export function buildTrackerPayload(dueToday: Task[], overdue: Task[]): string {
    const lines: string[] = [];

    if (overdue.length === 1) {
        lines.push(`Overdue: "${overdue[0].title}"`);
    } else if (overdue.length > 1) {
        lines.push(`${overdue.length} overdue tasks`);
    }

    if (dueToday.length === 1) {
        lines.push(`Due today: "${dueToday[0].title}"`);
    } else if (dueToday.length > 1) {
        lines.push(`${dueToday.length} tasks due today`);
    }

    const total = dueToday.length + overdue.length;
    const title = total === 1 ? 'Task Reminder' : `${total} Task Reminders`;

    const payload: PushPayload = {
        title,
        body: lines.join('\n'),
        icon: '/android-chrome-192x192.png',
        tag: 'simpletracker-push',
        data: { url: '/tasks' },
    };

    return JSON.stringify(payload);
}

// =============================================================================
// simpleBudget
// =============================================================================

export function buildBudgetPayload(transactions: Transaction[]): string {
    let body: string;

    if (transactions.length === 1) {
        const tx = transactions[0];
        const formattedAmount = formatCurrency(tx.amount);
        body = `Tomorrow: "${tx.title}" (${formattedAmount})`;
    } else {
        const totalAmount = transactions.reduce((sum, tx) => sum + tx.amount, 0);
        const formattedTotal = formatCurrency(totalAmount);
        body = `${transactions.length} transactions tomorrow (${formattedTotal} total)`;
    }

    const title = transactions.length === 1
        ? 'Transaction Reminder'
        : `${transactions.length} Transaction Reminders`;

    const payload: PushPayload = {
        title,
        body,
        icon: '/android-chrome-192x192.png',
        tag: 'simplebudget-push',
        data: { url: '/transactions' },
    };

    return JSON.stringify(payload);
}

// =============================================================================
// Helpers
// =============================================================================

function formatCurrency(amount: number): string {
    // Simple formatting — the worker doesn't know the user's locale/currency
    // so we just format as a number with 2 decimal places
    return `$${Math.abs(amount).toFixed(2)}`;
}
