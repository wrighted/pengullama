from transformers import AutoModelForCausalLM, AutoTokenizer

# Load the model and tokenizer
model_name = "wrighted/zephllama"
tokenizer = AutoTokenizer.from_pretrained("unsloth/Meta-Llama-3.1-8B-bnb-4bit")
model = AutoModelForCausalLM.from_pretrained("unsloth/Meta-Llama-3.1-8B-bnb-4bit")

# Define your input prompt
prompt = "Your prompt here"

# Tokenize the input
inputs = tokenizer(prompt, return_tensors="pt")

# Generate output using the model
outputs = model.generate(inputs["input_ids"], max_length=128, do_sample=True)

# Decode and print the result
response = tokenizer.decode(outputs[0], skip_special_tokens=True)
print(response)