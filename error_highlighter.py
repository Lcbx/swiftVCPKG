#!python

import sys

    
if __name__ == "__main__":

    if not sys.stdin.isatty():
        combined_output = sys.stdin.read()
    elif len(sys.argv) > 1:
        combined_output = ' '.join(sys.argv[1:])
    else:
        print("Please provide input text via stdin or command line argument.")
        sys.exit(1)


    # ANSI escape code for bold
    RED = '\033[91m'
    RESET = '\033[0m'

    # match error lines
    import re

    ## to keep the rest
    # filtered_output = re.sub(
    #    r'(?P<error>[\w\-/\.]+:\d+:\d+:\s+error:.*)',
    #    lambda match:f"{RED}{match.group('error')}{RESET}", 
    #    combined_output)

    filtered_output = ''.join(map(
        lambda s:f"{RED}{s}{RESET}\n",
        re.findall(r'([\w\-/\.]+:\d+:\d+:\s+error:.*|error:.*)', combined_output)
    ))

    if filtered_output:
        print(filtered_output)
        sys.exit(1)
    sys.exit(0)
