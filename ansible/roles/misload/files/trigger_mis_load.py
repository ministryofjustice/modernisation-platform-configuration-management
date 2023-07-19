import argparse
import winrm


def run_batch_file(target, port, username, password, batch_file):
    try:
        session = winrm.Session(
            f"http://{target}:{port}", auth=(username, password), transport='ntlm')
        r = session.run_cmd('cmd.exe', ['/C', batch_file])
        if r.status_code == 0:
            print("Batch file executed successfully.")
        else:
            print("Unable to execute the batch file. Status code: {}".format(
                r.status_code))
    except Exception as e:
        print("An error occurred while trying to execute the batch file:", str(e))


def main():
    parser = argparse.ArgumentParser(
        description='Run a batch file on target machine via WinRM')
    parser.add_argument('-u', '--username', help='Username', required=True)
    parser.add_argument('-p', '--password', help='Password', required=True)
    parser.add_argument('-t', '--target', help='Target machine', required=True)
    parser.add_argument('-o', '--port', help='Port number', default=5985)
    parser.add_argument(
        '-b', '--batch', help='Path to the batch file on the target machine', required=True)

    args = parser.parse_args()

    run_batch_file(args.target, args.port, args.username,
                   args.password, args.batch)


if __name__ == '__main__':
    main()
