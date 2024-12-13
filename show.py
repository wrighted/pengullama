import json
import argparse

def main(filename):
    # Load the JSON data from the specified file
    with open(filename, 'r') as file:
        json_out = file.read()

    # Load the JSON string into a Python dictionary
    data = json.loads(json_out)

    # Create the alpaca_prompt using formatted strings
    alpaca_prompt = """
Original commit:
https://github.com/zephyrproject-rtos/zephyr/commit/{}

### Instruction:
{}

### Input:
{}

### Tokenized:
{}

### Error location:
{}

### Error correction:
{}

### Response:
{}"""

    for point in data:

        # Format and print the prompt using data from the JSON
        formatted_prompt = alpaca_prompt.format(
            point['commit_hash'],
            point['instruction'],
            point['input'],
            point['tokenized'],
            point['error_location'],
            point['error_correction'],
            point['response']
        )

        # Print the formatted prompt
        print(formatted_prompt)

if __name__ == "__main__":
    # Set up argument parsing
    parser = argparse.ArgumentParser(description='Process a JSON file and format it into an Alpaca prompt.')
    parser.add_argument('filename', type=str, help='The filename containing JSON data.')

    # Parse the arguments
    args = parser.parse_args()

    # Call the main function with the provided filename
    main(args.filename)
