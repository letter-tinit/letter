#!/usr/bin/env python3
"""Generate a deterministic, importable Letter backup covering 365 days."""

from __future__ import annotations

import calendar
import json
import sys
import uuid
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path


NAMESPACE = uuid.UUID("7dd8be17-d237-4a5c-a0f1-7c572c5e19a4")
START = date(2025, 8, 19)
END = date(2026, 8, 18)
EXPORTED_AT = "2026-08-18T12:00:00Z"


def uid(key: str) -> str:
    return str(uuid.uuid5(NAMESPACE, key)).upper()


def iso(day: date, hour: int = 0, minute: int = 0) -> str:
    return datetime.combine(day, time(hour, minute), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def months_between(start: date, end: date) -> list[date]:
    result = []
    current = date(start.year, start.month, 1)
    while current <= end:
        result.append(current)
        current = date(current.year + (current.month == 12), current.month % 12 + 1, 1)
    return result


def bucket_kind(name: str) -> dict:
    return {name: {}}


def make_finance(months: list[date]) -> dict:
    transactions = []
    budgets = []

    for month_index, month in enumerate(months):
        income = 28_000_000 + month_index * 250_000
        days_in_month = calendar.monthrange(month.year, month.month)[1]
        transaction_specs = [
            (2, "income", "salary", "banking", income, "Monthly salary"),
            (3, "expense", "housing", "banking", 6_500_000, "Apartment rent"),
            (6, "expense", "food", "card", 1_850_000 + month_index * 20_000, "Groceries"),
            (10, "expense", "transport", "card", 620_000, "Metro and fuel"),
            (15, "expense", "housing", "banking", 930_000 + month_index * 15_000, "Utilities"),
            (20, "expense", "entertainment", "card", 780_000, "Leisure"),
            (25, "expense", "investment", "banking", 3_000_000 + month_index * 100_000, "Index fund"),
        ]
        for day_number, tx_type, category, method, amount, note in transaction_specs:
            occurred = date(month.year, month.month, min(day_number, days_in_month))
            if START <= occurred <= END:
                key = f"finance-transaction-{month:%Y-%m}-{category}-{day_number}"
                transactions.append({
                    "id": uid(key),
                    "note": note,
                    "type": tx_type,
                    "category": category,
                    "method": method,
                    "amount": amount,
                    "occurredAt": iso(occurred, 12),
                    "createAt": iso(occurred, 12, 5),
                })

        budget_id = uid(f"budget-{month:%Y-%m}")
        allocation_defs = [("needs", 0.5), ("wants", 0.3), ("savings", 0.2)]
        allocations = []
        budget_transactions = []
        plans = []

        for kind, ratio in allocation_defs:
            allocation_id = uid(f"allocation-{month:%Y-%m}-{kind}")
            allocation_transaction_ids = []
            allocation_plan_ids = []

            if kind == "needs":
                for plan_name, amount, day_number in [
                    ("Rent", 6_500_000, 3),
                    ("Utilities", 950_000, 15),
                    ("Transport", 650_000, 10),
                ]:
                    plan_id = uid(f"plan-{month:%Y-%m}-{plan_name}")
                    tx_id = uid(f"budget-tx-{month:%Y-%m}-{plan_name}")
                    occurred = date(month.year, month.month, min(day_number, days_in_month))
                    is_in_range = START <= occurred <= END
                    allocation_plan_ids.append(plan_id)
                    if is_in_range:
                        allocation_transaction_ids.append(tx_id)
                    plan = {
                        "id": plan_id,
                        "allocationID": allocation_id,
                        "name": plan_name,
                        "amount": amount,
                        "amountType": "fixed" if plan_name == "Rent" else "estimated",
                    }
                    if is_in_range:
                        plan["transactionID"] = tx_id
                        budget_transactions.append({
                            "id": tx_id,
                            "allocationID": allocation_id,
                            "type": "expense",
                            "title": plan_name,
                            "note": f"{plan_name} payment for {month:%m/%Y}",
                            "occurredAt": iso(occurred, 11),
                            "amount": amount,
                            "paymentMethod": "banking",
                            "fixedExpensePlanID": plan_id,
                        })
                    plans.append(plan)
            elif kind == "wants":
                tx_id = uid(f"budget-tx-{month:%Y-%m}-Leisure")
                occurred = date(month.year, month.month, min(20, days_in_month))
                if START <= occurred <= END:
                    allocation_transaction_ids.append(tx_id)
                    budget_transactions.append({
                        "id": tx_id,
                        "allocationID": allocation_id,
                        "type": "expense",
                        "title": "Leisure",
                        "note": "Books, coffee and weekend activities",
                        "occurredAt": iso(occurred, 18),
                        "amount": 1_200_000 + month_index * 25_000,
                        "paymentMethod": "card",
                    })
            else:
                tx_id = uid(f"budget-tx-{month:%Y-%m}-Investment")
                occurred = date(month.year, month.month, min(25, days_in_month))
                if START <= occurred <= END:
                    allocation_transaction_ids.append(tx_id)
                    budget_transactions.append({
                        "id": tx_id,
                        "allocationID": allocation_id,
                        "type": "expense",
                        "title": "Long-term investment",
                        "note": "Monthly index-fund contribution",
                        "occurredAt": iso(occurred, 9),
                        "amount": round(income * ratio),
                        "paymentMethod": "banking",
                    })

            allocations.append({
                "id": allocation_id,
                "kind": bucket_kind(kind),
                "ratio": ratio,
                "targetAmount": round(income * ratio),
                "transactions": allocation_transaction_ids,
                "fixedExpensePlans": allocation_plan_ids,
            })

        budgets.append({
            "id": budget_id,
            "periodStart": iso(month),
            "income": income,
            "method": "fiftyThirtyTwenty",
            "createdAt": iso(month, 0, 5),
            "allocations": allocations,
            "fixedExpensePlans": plans,
            "transactions": budget_transactions,
        })

    item_specs = [
        ("cashAndCashEquivalents", "Cash and bank accounts"),
        ("financialAssets", "Index funds"),
        ("tangibleAssets", "Motorbike"),
        ("shortTermDebt", "Credit card"),
        ("longTermDebt", "Personal loan"),
    ]
    plan_items = []
    item_ids = {}
    for order, (category, name) in enumerate(item_specs):
        item_id = uid(f"networth-item-{category}")
        item_ids[category] = item_id
        plan_items.append({
            "id": item_id,
            "category": category,
            "name": name,
            "displayOrder": order,
        })

    snapshots = []
    for month_index, month in enumerate(months):
        if month == months[0]:
            snapshot_day = START.day
        elif month == months[-1]:
            snapshot_day = END.day
        else:
            snapshot_day = calendar.monthrange(month.year, month.month)[1]
        snapshot_date = date(month.year, month.month, snapshot_day)
        amounts = {
            "cashAndCashEquivalents": 45_000_000 + month_index * 1_350_000,
            "financialAssets": 80_000_000 + month_index * 4_200_000,
            "tangibleAssets": max(18_000_000 - month_index * 350_000, 12_000_000),
            "shortTermDebt": max(4_800_000 - month_index * 180_000, 500_000),
            "longTermDebt": max(72_000_000 - month_index * 3_200_000, 25_000_000),
        }
        snapshots.append({
            "id": uid(f"networth-snapshot-{month:%Y-%m}"),
            "asOfDate": iso(snapshot_date, 23, 59),
            "values": [
                {
                    "id": uid(f"networth-value-{month:%Y-%m}-{category}"),
                    "amount": amount,
                    "planItemID": item_ids[category],
                }
                for category, amount in amounts.items()
            ],
        })

    balance_months = [
        {
            "monthStart": iso(month),
            "isLocked": month == months[-1],
        }
        for month in months
    ]

    return {
        "schemaVersion": 2,
        "backupDate": EXPORTED_AT,
        "transactions": transactions,
        "budgets": budgets,
        "netWorthPlanItems": plan_items,
        "netWorthSnapshots": snapshots,
        "balanceMonths": balance_months,
    }


def make_habits() -> dict:
    definitions = [
        ("Morning water", "Drink enough water throughout the day", "drop.fill", "#4ECDC4", "daily", [], "count", 8, "glasses", 7),
        ("Read books", "Read before sleeping", "book.fill", "#6C5CE7", "daily", [], "count", 20, "pages", 21),
        ("Morning exercise", "Move before starting work", "figure.run", "#FD8A5E", "weekday", [], "todo", 1, "session", 6),
        ("Meditation", "A quiet moment to reset", "figure.mind.and.body", "#50C878", "daily", [], "count", 10, "minutes", 22),
        ("Weekly finance review", "Review spending and prepare the next week", "chart.line.uptrend.xyaxis", "#4169E1", "custom", [0], "todo", 1, "review", 19),
        ("Practice guitar", "Practice chords and one full song", "guitars.fill", "#E0115F", "custom", [2, 4, 6], "count", 30, "minutes", 20),
    ]
    habits = []
    total_completions = 0
    longest_overall = 0

    for sort_order, definition in enumerate(definitions):
        name, description, icon, color, frequency, target_days, goal_type, goal_count, unit, reminder_hour = definition
        habit_id = uid(f"habit-{name}")
        entries = []
        completed_dates = []
        current = START
        day_index = 0
        while current <= END:
            swift_weekday = (current.weekday() + 1) % 7
            scheduled = (
                frequency == "daily"
                or (frequency == "weekday" and 1 <= swift_weekday <= 5)
                or (frequency == "weekend" and swift_weekday in (0, 6))
                or (frequency == "custom" and swift_weekday in target_days)
            )
            if scheduled:
                skipped = (day_index + sort_order * 7) % 53 == 0
                if goal_type == "todo":
                    completed_count = 0 if (day_index + sort_order) % 8 == 0 else 1
                else:
                    shortfall = (day_index + sort_order * 3) % 9 == 0
                    completed_count = max(0, goal_count - (2 if shortfall else 0))
                if skipped:
                    completed_count = 0
                status = "skipped" if skipped else "active"
                if not skipped and completed_count >= goal_count:
                    completed_dates.append(current)
                    total_completions += completed_count
                note = ""
                if day_index % 29 == 0:
                    note = "Felt consistent and focused today."
                entries.append({
                    "id": uid(f"habit-entry-{name}-{current.isoformat()}"),
                    "date": iso(current),
                    "completedCount": completed_count,
                    "status": status,
                    "note": note,
                    "mood": 3 + ((day_index + sort_order) % 3),
                    "createdAt": iso(current, 21),
                    "updatedAt": iso(current, 21, 5),
                })
            current += timedelta(days=1)
            day_index += 1

        longest_streak = min(46 - sort_order * 3, len(completed_dates))
        longest_overall = max(longest_overall, longest_streak)
        archived = name == "Practice guitar"
        archive_date = date(2026, 5, 31) if archived else None
        if archived:
            entries = [entry for entry in entries if entry["date"] <= iso(archive_date, 23, 59)]
            completed_dates = [day for day in completed_dates if day <= archive_date]

        reminder_id = uid(f"habit-reminder-{name}")
        habits.append({
            "id": habit_id,
            "name": name,
            "habitDescription": description,
            "icon": icon,
            "colorHex": color,
            "createdAt": iso(START, 7),
            **({"archivedAt": iso(archive_date, 23, 59)} if archived else {}),
            "sortOrder": sort_order,
            "seriesID": habit_id,
            "versionNumber": 1,
            "startDate": iso(START),
            **({"endDate": iso(archive_date, 23, 59)} if archived else {}),
            "frequency": frequency,
            "targetDaysOfWeek": target_days,
            "reminderTime": iso(START, reminder_hour),
            "goalType": goal_type,
            "goalCount": goal_count,
            "goalUnit": unit,
            "currentStreak": min(12, longest_streak) if not archived else 0,
            "longestStreak": longest_streak,
            **({"lastCompletedDate": iso(completed_dates[-1])} if completed_dates else {}),
            "entries": entries,
            "reminders": [{
                "id": reminder_id,
                "time": iso(START, reminder_hour),
                "daysOfWeek": target_days,
                "isEnabled": not archived,
                "notificationID": f"letter.test.{reminder_id.lower()}",
            }],
        })

    return {
        "schemaVersion": 1,
        "exportedAt": EXPORTED_AT,
        "profile": {
            "id": uid("profile-test-user"),
            "displayName": "Letter Test Year",
            "weekStartsOnMonday": True,
            "usesSimplifiedStatisticsMode": False,
            "defaultReminderTime": iso(START, 7),
            "colorScheme": "system",
            "themeColorHex": "#4ECDC4",
            "totalCompletions": total_completions,
            "totalHabitsCreated": len(definitions),
            "longestOverallStreak": longest_overall,
            "joinedAt": iso(START),
        },
        "habits": habits,
    }


def main() -> None:
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("LetterFullYearBackup.json")
    months = months_between(START, END)
    backup = {
        "schemaVersion": 1,
        "exportedAt": EXPORTED_AT,
        "earliestMonth": iso(date(START.year, START.month, 1)),
        "finance": make_finance(months),
        "habits": make_habits(),
    }
    output.write_text(json.dumps(backup, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
