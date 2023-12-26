import os
import signal
import psutil
from board import SCL, SDA
import busio
import adafruit_ssd1306

def find_process_id_by_name(process_name):
    """
    Get a list of all the PIDs of all the running process whose name contains
    the given string process_name.
    """
    list_of_process_ids = []
    for proc in psutil.process_iter():
        try:
            pinfo = proc.as_dict(attrs=['pid', 'name', 'cmdline'])
            # Check if the full command line contains the process_name
            if process_name.lower() in ' '.join(pinfo['cmdline']).lower():
                list_of_process_ids.append(pinfo['pid'])
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return list_of_process_ids

def main():
    pids = find_process_id_by_name('/usr/local/bin/ssd1306_display')
    if pids:
        pid = pids[0]
        try:
            os.kill(pid, signal.SIGTERM)
            print("Blanked out OLED screen to avoid burn-in. Shutdown signal sent to the background app.")

            i2c = busio.I2C(SCL, SDA)
            disp = adafruit_ssd1306.SSD1306_I2C(128, 32, i2c)
            disp.fill(0)
            disp.show()

        except ProcessLookupError:
            print("Invalid PID or process not found.")
    else:
        print("ssd1306_display process not found.")

if __name__ == "__main__":
    main()
