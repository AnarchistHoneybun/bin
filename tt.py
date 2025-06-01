#!/usr/bin/env python3

import json
import os
import sys
import time
import argparse
import urllib.request
import urllib.error
import subprocess
import re
from datetime import datetime, timedelta

TRACKING_FILE = "thread_tracker.json"
DEFAULT_CHECK_INTERVAL = 120  # 2 minutes in seconds

def load_tracking_data():
    """Load tracking data from JSON file"""
    if os.path.exists(TRACKING_FILE):
        try:
            with open(TRACKING_FILE, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return {"threads": {}, "next_id": 1}
    return {"threads": {}, "next_id": 1}

def save_tracking_data(data):
    """Save tracking data to JSON file"""
    with open(TRACKING_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def parse_thread_url(url):
    """Parse 4chan thread URL to extract board and thread_id"""
    # Match pattern: https://boards.4chan.org/{board}/thread/{thread_id}
    pattern = r'https://boards\.4chan\.org/([^/]+)/thread/(\d+)'
    match = re.match(pattern, url)
    if match:
        return match.group(1), match.group(2)
    else:
        raise ValueError(f"Invalid 4chan thread URL: {url}")

def fetch_thread_data(board, thread_id):
    """Fetch thread data from 4chan API"""
    api_url = f"https://a.4cdn.org/{board}/thread/{thread_id}.json"
    try:
        with urllib.request.urlopen(api_url) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None  # Thread doesn't exist or was archived
        raise
    except Exception as e:
        print(f"Error fetching thread data: {e}")
        return None

def get_thread_title(thread_data):
    """Extract thread title from the first post"""
    if not thread_data or 'posts' not in thread_data:
        return "Unknown Thread"
    
    first_post = thread_data['posts'][0]
    
    # Try subject first, then fall back to truncated comment
    if 'sub' in first_post and first_post['sub']:
        return first_post['sub']
    elif 'com' in first_post and first_post['com']:
        # Strip HTML tags and truncate
        comment = re.sub(r'<[^>]+>', '', first_post['com'])
        return comment[:50] + "..." if len(comment) > 50 else comment
    else:
        return f"Thread {first_post.get('no', 'Unknown')}"

def send_notification(board, thread_id, post_content):
    """Send desktop notification using notify-send"""
    title = f"/{board}/ - {thread_id}"
    # Truncate and clean post content
    content = re.sub(r'<[^>]+>', '', post_content)  # Remove HTML tags
    if len(content) > 200:
        content = content[:200] + "..."
    
    try:
        subprocess.run(['notify-send', title, content], check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"Failed to send notification: {title} - {content}")

def add_thread(board, thread_id, check_interval=DEFAULT_CHECK_INTERVAL):
    """Add a thread to tracking"""
    data = load_tracking_data()
    
    # Check if thread already exists
    thread_key = f"{board}_{thread_id}"
    if thread_key in data["threads"]:
        print(f"Thread /{board}/{thread_id} is already being tracked")
        return
    
    # Fetch initial thread data
    thread_data = fetch_thread_data(board, thread_id)
    if not thread_data:
        print(f"Could not fetch thread /{board}/{thread_id} - it may not exist")
        return
    
    # Get the last post number to track new posts from this point
    last_post_no = thread_data['posts'][-1]['no']
    thread_title = get_thread_title(thread_data)
    
    # Add to tracking
    tracking_id = data["next_id"]
    data["threads"][thread_key] = {
        "id": tracking_id,
        "board": board,
        "thread_id": thread_id,
        "title": thread_title,
        "last_post_no": last_post_no,
        "last_update": time.time(),
        "check_interval": check_interval,
        "added_time": time.time()
    }
    data["next_id"] += 1
    
    save_tracking_data(data)
    print(f"Now tracking /{board}/{thread_id} - {thread_title} (ID: {tracking_id:03d})")

def list_threads():
    """List all currently tracked threads"""
    data = load_tracking_data()
    
    if not data["threads"]:
        print("No threads currently being tracked")
        return
    
    # Group by board
    boards = {}
    for thread_key, thread_info in data["threads"].items():
        board = thread_info["board"]
        if board not in boards:
            boards[board] = []
        boards[board].append(thread_info)
    
    # Sort threads within each board by last update (most recent first)
    for board in boards:
        boards[board].sort(key=lambda x: x["last_update"], reverse=True)
    
    # Display
    for board in sorted(boards.keys()):
        print(f"\nBoard: /{board}/")
        print("ID  | Title                    | Last Update")
        print("-" * 50)
        
        for thread in boards[board]:
            last_update = datetime.fromtimestamp(thread["last_update"])
            time_diff = datetime.now() - last_update
            
            if time_diff.days > 0:
                time_str = f"{time_diff.days}d ago"
            elif time_diff.seconds > 3600:
                time_str = f"{time_diff.seconds // 3600}h ago"
            else:
                time_str = f"{time_diff.seconds // 60}m ago"
            
            title = thread["title"][:20] + "..." if len(thread["title"]) > 20 else thread["title"]
            print(f"{thread['id']:03d} | {title:<20} | {time_str}")

def remove_thread(tracking_id, force=False):
    """Remove a thread from tracking"""
    data = load_tracking_data()
    
    # Find thread by tracking ID
    thread_to_remove = None
    thread_key_to_remove = None
    
    for thread_key, thread_info in data["threads"].items():
        if thread_info["id"] == tracking_id:
            thread_to_remove = thread_info
            thread_key_to_remove = thread_key
            break
    
    if not thread_to_remove:
        print(f"No thread found with ID {tracking_id:03d}")
        return
    
    # Show thread info and ask for confirmation
    if not force:
        print(f"Thread: /{thread_to_remove['board']}/{thread_to_remove['thread_id']}")
        print(f"Title: {thread_to_remove['title']}")
        confirm = input("Stop tracking this thread? (y/n): ").lower().strip()
        if confirm != 'y':
            print("Cancelled")
            return
    
    # Remove thread
    del data["threads"][thread_key_to_remove]
    save_tracking_data(data)
    print(f"Stopped tracking thread {tracking_id:03d}")

def cleanup_old_threads():
    """Remove threads that haven't been updated in 24 hours"""
    data = load_tracking_data()
    current_time = time.time()
    cutoff_time = current_time - (24 * 60 * 60)  # 24 hours ago
    
    threads_to_remove = []
    for thread_key, thread_info in data["threads"].items():
        if thread_info["last_update"] < cutoff_time:
            threads_to_remove.append(thread_key)
    
    for thread_key in threads_to_remove:
        del data["threads"][thread_key]
    
    if threads_to_remove:
        save_tracking_data(data)
        print(f"Removed {len(threads_to_remove)} inactive threads")

def monitor_thread(board, thread_id, check_interval):
    """Monitor a single thread for updates"""
    data = load_tracking_data()
    thread_key = f"{board}_{thread_id}"
    
    if thread_key not in data["threads"]:
        print(f"Thread /{board}/{thread_id} is not being tracked")
        return
    
    thread_info = data["threads"][thread_key]
    print(f"Monitoring /{board}/{thread_id} - {thread_info['title']}")
    print(f"Check interval: {check_interval}s, Press Ctrl+C to stop")
    
    try:
        while True:
            thread_data = fetch_thread_data(board, thread_id)
            
            if not thread_data:
                print(f"Thread /{board}/{thread_id} no longer exists, removing from tracking")
                del data["threads"][thread_key]
                save_tracking_data(data)
                break
            
            # Check for new posts
            latest_post_no = thread_data['posts'][-1]['no']
            if latest_post_no > thread_info['last_post_no']:
                # Find new posts
                for post in reversed(thread_data['posts']):
                    if post['no'] > thread_info['last_post_no']:
                        post_content = post.get('com', 'No content')
                        send_notification(board, thread_id, post_content)
                
                # Update tracking info
                thread_info['last_post_no'] = latest_post_no
                thread_info['last_update'] = time.time()
                data["threads"][thread_key] = thread_info
                save_tracking_data(data)
                print(f"New posts detected in /{board}/{thread_id}")
            
            time.sleep(check_interval)
            
    except KeyboardInterrupt:
        print(f"\nStopped monitoring /{board}/{thread_id}")

def main():
    parser = argparse.ArgumentParser(description="4chan Thread Tracker")
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('-u', '--url', help='Track thread by URL')
    group.add_argument('-m', '--manual', nargs=2, metavar=('BOARD', 'THREAD_ID'), 
                      help='Track thread by board and thread ID')
    group.add_argument('-l', '--list', action='store_true', 
                      help='List currently tracked threads')
    group.add_argument('-d', '--delete', type=int, metavar='ID', 
                      help='Remove thread from tracking by ID')
    
    parser.add_argument('-i', '--interval', type=int, default=DEFAULT_CHECK_INTERVAL,
                       help=f'Check interval in seconds (default: {DEFAULT_CHECK_INTERVAL})')
    parser.add_argument('-f', '--force', action='store_true',
                       help='Force delete without confirmation')
    
    args = parser.parse_args()
    
    if args.list:
        list_threads()
    elif args.delete:
        remove_thread(args.delete, args.force)
    elif args.url:
        try:
            board, thread_id = parse_thread_url(args.url)
            add_thread(board, thread_id, args.interval)
            monitor_thread(board, thread_id, args.interval)
        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)
    elif args.manual:
        board, thread_id = args.manual
        add_thread(board, thread_id, args.interval)
        monitor_thread(board, thread_id, args.interval)
    
    # Clean up old threads
    cleanup_old_threads()

if __name__ == "__main__":
    main()