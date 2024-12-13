import os
import json
import argparse
from unsloth import FastLanguageModel
import torch

# Model parameters
model_name = "wrighted/zephllama_v0"
max_seq_length = 2048
dtype = None
load_in_4bit = True

# Load the model and tokenizer
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name=model_name,
    max_seq_length=max_seq_length,
    dtype=dtype,
    load_in_4bit=load_in_4bit,
)
FastLanguageModel.for_inference(model)

# Ensure GPU and CPU functionality
device_str = "cuda" if torch.cuda.is_available() else "cpu"
device = torch.device(device_str)
model.to(device)

def main(filename, num_points):
    # Load the JSON data from the specified file
    with open(filename, 'r') as file:
        json_out = file.read()

    # Load the JSON string into a Python dictionary
    data = json.loads(json_out)

    # Create the alpaca_prompt using formatted strings
    intended_result = """Original commit: https://github.com/zephyrproject-rtos/zephyr/commit/{commit_hash}

### Instruction:
{instruction}

### Input:
{input}

### Tokenized:
{tokenized}

### Error location:
{error_location}

### Error correction:
{error_correction}

### Response:
{response}"""

    llm_generated_result = """Below is an instruction that describes a task, paired with an input that provides further context. Complete the tokenized section, locate the error, and correct it.

### Instruction:
{instruction}

### Input:
{input}

### Tokenized:
{response}
"""

    # Process only the specified number of points
    for idx, point in enumerate(data[:num_points]):
        try:
            # Create the directory for the current commit
            commit_hash = point['commit_hash']
            output_dir = f"zeph_evaluated/{commit_hash}"
            os.makedirs(output_dir, exist_ok=True)

            # Format the target output
            target = intended_result.format(
                commit_hash=commit_hash,
                instruction=point['instruction'],
                input=point['input'],
                tokenized=point['tokenized'],
                error_location=point['error_location'],
                error_correction=point['error_correction'],
                response=point['response']
            )

            # Prepare the input prompt for the model
            formatted_input = point['input']
            instruction = point['instruction']
            alpaca_prompt_text = llm_generated_result.format(
                instruction=instruction,
                input=formatted_input,
                response=""
            )

            # Tokenize the input
            inputs = tokenizer(
                [alpaca_prompt_text],
                return_tensors="pt"
            ).to(device_str)

            # Generate the output using the model
            generated = model.generate(
                **inputs,
                max_new_tokens=max_seq_length,
                num_return_sequences=1
            )

            # Decode the generated output
            actual = tokenizer.decode(generated[0], skip_special_tokens=True)

            # Write the target and actual outputs to separate files
            with open(os.path.join(output_dir, "target.txt"), "w") as target_file:
                target_file.write(target)

            with open(os.path.join(output_dir, "actual.txt"), "w") as actual_file:
                actual_file.write(actual)

        except KeyError as e:
            print(f"Skipping data point {idx}: Missing required field. {e}")
        except Exception as e:
            print(f"Error processing data point {idx}: {e}")

if __name__ == "__main__":
    # Set up argument parsing
    parser = argparse.ArgumentParser(description='Process JSON file and save outputs into commit-specific directories.')
    parser.add_argument('filename', type=str, help='The filename containing JSON data.')
    parser.add_argument('--num_points', type=int, default=10, help='Number of data points to process.')

    # Parse the arguments
    args = parser.parse_args()

    # Call the main function with the provided filename
    main(args.filename, args.num_points)
