import requests
import threading

def check_proxy(proxy, working_proxy_file):
    try:
        url = "https://www.google.com"
        response = requests.get(url, proxies={'http': proxy, 'https': proxy}, timeout=5)
        if response.status_code == 200:
            print(f"Proxy {proxy} is working")
            with open(working_proxy_file, 'a') as wp_file:
                wp_file.write(f"{proxy}\n")
        else:
            print(f"Proxy {proxy} not working (Status Code: {response.status_code})")
    except Exception as e:
        print(f"Proxy {proxy} not working (Error: {e})")

def read_proxy_from_file(filepath):
    with open(filepath, 'r') as file:
        proxies = file.read().splitlines()
    return proxies

def main(num_threads):
    working_proxies_file_path = "working_proxies.txt"
    proxy_file_path = "proxies.txt"
    proxies = read_proxy_from_file(proxy_file_path)
    threads = []
    for proxy in proxies:
        thread = threading.Thread(target=check_proxy, args=(proxy, working_proxies_file_path))
        thread.start()
        threads.append(thread)
        # This if statement is the most important because we want to limit the number of threads
        if len(threads) >= num_threads:
            for t in threads:
                t.join()
            threads = []  # delay the program flow of execution.
    for thread in threads:
        thread.join()

main(5)

