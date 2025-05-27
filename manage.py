#!/usr/bin/env python3
import subprocess
import sys

def run_command(cmd, description):
    print(f"🔄 {description}...")
    result = subprocess.run(cmd, shell=True)
    if result.returncode != 0:
        print(f"❌ {description} failed")
        sys.exit(1)
    print(f"✅ {description} completed")

def main():
    if len(sys.argv) < 2:
        print("Commands: setup-dev, run, test")
        return
    
    cmd = sys.argv[1]
    if cmd == "setup-dev":
        run_command("pip install -r requirements.txt", "Installing dependencies")
    elif cmd == "run":
        run_command("uvicorn main:app --reload --port 8000", "Starting server")
    elif cmd == "test":
        run_command("pytest test_main.py -v", "Running tests")

if __name__ == "__main__":
    main()
