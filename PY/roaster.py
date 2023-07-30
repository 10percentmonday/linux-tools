#!/usr/bin/env python3
from datetime import datetime, timedelta
from calendar import month_name
import argparse

def is_working_day(date):
    pattern = [True, True, True, False, False, True, True, False, False, False, True, True, False, False]
    group_size = 14
    start_date = datetime(2023, 7, 15)
    days_since_start = (date - start_date).days
    pattern_index = days_since_start % len(pattern)
    return pattern[pattern_index]

def get_next_working_schedule(start_date, num_months):
    current_date = start_date
    working_days = []
    non_working_days = []

    for _ in range(num_months):
        month = current_date.month
        month_name_str = month_name[month]
        working_days.append((month_name_str, []))
        non_working_days.append((month_name_str, []))

        for _ in range(31):  # Iterate for the maximum number of days in a month
            if current_date.month != month:
                month = current_date.month
                month_name_str = month_name[month]
                working_days.append((month_name_str, []))
                non_working_days.append((month_name_str, []))

            if is_working_day(current_date):
                working_days[-1][1].append(current_date)
            else:
                non_working_days[-1][1].append(current_date)
            current_date += timedelta(days=1)

    return working_days, non_working_days

def print_schedule(working_schedule, non_working_schedule):
    print("Working Schedule:")
    for month, dates in working_schedule:
        print(f"\n{month}:")
        for date in dates:
            print(date.strftime("%d/%m/%Y"))

    print("\nNon-Working Schedule:")
    for month, dates in non_working_schedule:
        print(f"\n{month}:")
        for date in dates:
            print(date.strftime("%d/%m/%Y"))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate working and non-working schedules")
    parser.add_argument("-m", "--num_months", type=int, default=2, help="Number of months to generate schedules for")
    parser.add_argument("-d", "--start_date", type=str, default="2023-07-15", help="Start date in YYYY-MM-DD format")
    args = parser.parse_args()

    num_months = args.num_months
    start_date = datetime.strptime(args.start_date, "%Y-%m-%d")
    working_schedule, non_working_schedule = get_next_working_schedule(start_date, num_months)
    print_schedule(working_schedule, non_working_schedule)
