import argparse
import winrm

def check_winrm_connection(target, username, password, port):
    try:
        session = winrm.Session(f"http://{target}:{port}", auth=(username, password), transport='ntlm')
        r = session.run_cmd('ipconfig', ['/all'])
        if r.status_code == 0:
            print("WinRM connection established successfully.")
        else:
            print("Unable to establish WinRM connection. Status code: {}".format(r.status_code))
    except Exception as e:
        print("An error occurred while trying to establish WinRM connection:", str(e))

def main():
    parser = argparse.ArgumentParser(description='Check WinRM connection')
    parser.add_argument('-u', '--username', help='Username', required=True)
    parser.add_argument('-p', '--password', help='Password', required=True)
    parser.add_argument('-t', '--target', help='Target machine', required=True)
    parser.add_argument('-o', '--port', help='Target port', default=5985)

    args = parser.parse_args()

    check_winrm_connection(args.target, args.username, args.password, args.port)

if __name__ == '__main__':
    main()
