from unsloth import FastLanguageModel
from transformers import TextStreamer
import torch
import argparse
import warnings

# We don't want warnings to be printed
warnings.filterwarnings("ignore")

# Parameters
model_name = "wrighted/zephllama"
max_seq_length = 1024
dtype = None
load_in_4bit = True

# Set up command-line argument parsing for the prompt
parser = argparse.ArgumentParser(description="Generate text using a fine-tuned model.")
parser.add_argument("instruction", type=str, help="The instruction for the model.")
parser.add_argument("input", type=str, help="The input for the model.")
args = parser.parse_args()

# Function to replace escape characters with formatted text
def format_input(input_text):
    formatted_text = input_text.replace("\\n", "\n").replace("\\t", "\t")
    return formatted_text

formatted_input = format_input(args.input)

# Load the model and tokenizer
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = model_name,
    max_seq_length = max_seq_length,
    dtype = dtype,
    load_in_4bit = load_in_4bit,
)
FastLanguageModel.for_inference(model)

# Ensure GPU and CPU functionality
device_str = "cuda" if torch.cuda.is_available() else "cpu"
device = torch.device(device_str)
model.to(device)

alpaca_prompt = """Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
{}

### Input:
{}

### Response:
{}"""

inputs = tokenizer(
[
    alpaca_prompt.format(
        args.instruction,
        formatted_input,
        "",
    )
], return_tensors = "pt").to(device_str)

# Decode and print the result
text_streamer = TextStreamer(tokenizer)
_ = model.generate(**inputs, streamer = text_streamer, max_new_tokens = max_seq_length, num_return_sequences = 1)
