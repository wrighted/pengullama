# pengullama

This repository contains work completed as part of my honours project.

## Usage

There are a few usfule scripts included in this repository.

### Promptify

`promptify` is a bash script which will turn a git repository into training data
suitable for an LLM of your choice. Read further below for its justification,
but generally use the script in any git repository:

     ./promptify.sh <num_commits> <file_mask> <evaluation_commits> <max_tokens> > <output_file>

Where:

- `<num_commits>` is the number of training points to extract (reverse chronologically),
- `<file_mask>` is a file mask to apply to the commit search (ex. `.[ch]`),
- `<evaluation_commits>` is the number of commits to exclude from training output and instead save for testing later,
- `<max_tokens>` is the maximum token to allow in training data,
- `<output_file>` is the file to store the training data as JSON.

### Ask

`ask` is a python script which can ask a LLM saved in HuggingFace a question. It is intended to be used
on models which follow an Alpaca prompt style. It can be used as follows:

     python3 ask.py <instruction> <input>

Where:

- `<instruction>` is the instrcution of your desired prompt,
- `<input>` is the input (usually code) of your desired prompt.

It will output the LLMs generated response to `stdout`.

NOTE: The target model can be changes within the script.

### Show

`show` is a python script which will take training JSON data and display it in a readable format.
It can be used as follows:

     python3 show.py <json_file>

Where:

- `<json_file>` is a properly formatted JSON file.

## Fine-tuning LLMs for Software Development Tasks

### Training LLMs

The initial deliverable for this project involves the training and fine-tuning of an open-source
large language model (LLM) on a proprietary code base. The primary goal is to adapt the model
to a specialized domain by exposing it to code it has not previously encountered, enhancing its
understanding and capabilities within this specific context. Success will be measured by
comparing the performance of the fine-tuned model against the original untuned version, with
the expectation that the fine-tuned model will outperform the baseline when tasked with
generating, analyzing, or reasoning about the proprietary code. This deliverable will serve as a
foundation for further experimentation and model refinement.

### Training LLMs on an open source Kernel

The next phase of this project will involve expanding the training data to include the git history
of a large open-source kernel, such as Linux or Zephyr. The objective is to further specialize
the model by incorporating a broader and more complex dataset. Techniques such as
tokenization, adjustments to model size, and tuning batch size will be employed to optimize the
training process. Refining the training and test datasets to align with the context of kernel
development will be key to ensuring the model's effectiveness. An example task is automated
program repair (APR). As with the previous phase, success will be evaluated by comparing the
model's performance in response to targeted prompts against a default baseline. The
expectation is improved results due to the specialized training.

### Evaluating fine-tuned LLM

Assuming the fine-tuned LLM proves effective for software development tasks, the final
deliverable will focus on evaluating its practical application in real-world scenarios. This phase
will involve prompting the LLM to address previously unseen software development challenges,
such as resolving open bugs in the Linux Kernel, and validating the accuracy and viability of its
proposed solutions. By comparing its performance against other LLMs and traditional static
analysis tools, we will assess whether the fine-tuned LLM offers a tangible advantage. This
evaluation will determine whether fine-tuned LLMs are sufficiently advanced to be considered a
valuable asset for field deployment in software development today.

## Set-up

There are few requirements in order to re-produce the results of this project:

- You need to have a CUDA capable GPU in order to use the LLM,
- You need a GPU with 16GB of VRAM in order to train the LLM,
- You need to be on a distribution of Linux for full compatability,
- You need Python and a few installed packages via `pip` (container in progress)
    - unsloth
    - bitsandbytes
    - torch
- You need a Hugging Face account in order to access my trained models.

## Progress

Below is the week-by-week summary of progress towards this projects goals.

### Week 1

Set up proposed devleopment environment in order to train llama:

    - RTX 2060 Super
    - WSL
    - Unsloth

Using unsloth, trained llama 3.1 8B on one "fake" data point.

Challenges:

- Memroy usage was too high for llama 3.1 8B, so had to quantize to 4 bits.
- One data point is obviously not enough to train a model, but all my GPU can handle.

For more details see [this notebook](./notebooks/week_1.ipynb). Which inludes
_most_ of the necesarry set-up steps for my environment and accounts.

### Week 2

Wrote a script in bash to format git repostories to conform to Aplaca prompt standard, where:

- The commit message is the instruction,
- Pre-commit code is the input, and
- Git diff line changes are the result.

For more details on the sctipt see [the script](./promptify.sh).

I Attempted to train llama 3.1 8B on latest 100 commits of Zephyr, but quickly
ran out of memory when adding any more than 1 data point on my local system. Was not sucessful
in memory minimization by adjusting parameters and using less data.

I ported code to Google Colab, which provides a Tesla T4 runtime for free!

Uploaded resulting model to my [Hugging Face](https://huggingface.co/wrighted/zephllama).

See [this notebook](./notebooks/week_2.ipynb) for more details.

### Week 3 

I wrote a Python script which downloads and computes my tained model on my local system.
This way, I have an easy way to interact with my LLM outside of a notebook.

Since my model performed poorly, I made a few changes to my input data:

- No longer refernce file names, _only_ the lines of code with +/-
- Only inlclude commits that change _at most_ 25 lines,
- Expand to use 1000 commits, and 3 full training epochs.

This took just over an hour of training on Google Colab T4, afer which
I quickly ran out of credits. It's unclear when I will get more.

After testing around with this new model, it seems much more well-rounded
and clearly is taking to the training:

```
### Instruction:
Bluetooth: Mesh: Fix bugs in PTS testing

### Input:
        BT_MESH_MODEL_CB(BT_MESH_MODEL_ID_BRG_CFG_SRV, bt_mesh_brg_cfg_srv_op,     \
                         NULL, NULL, &bt_mesh_brg_cfg_srv_cb)
                                brg_tbl_compact();
                entry.directions = 0;

### Response:
-       BT_MESH_MODEL_CB(BT_MESH_MODEL_ID_BRG_CFG_SRV, bt_mesh_brg_cfg_srv_op,     \
-                        NULL, NULL, &bt_mesh_brg_cfg_srv_cb)
-                               brg_tbl_compact();
+       BT_MESH_MODEL_CB(BT_MESH_MODEL_ID_BRG_CFG_SRV, &bt_mesh_brg_cfg_srv_cb)
+               /* Do not call brg_tbl_compact() here as it is called in
+                * brg_tbl_update() when a model is added to a bridge.
+                */
-               entry.directions = 0;
+               entry.directions = BT_MESH_BRG_DIR_NONE;<|end_of_text|>
```

You can notice the gif diff of +/- which would not be in stock LLAMA.

### Week 4

Since it's clear that my model is learning, I'm choosing to focus on
feature engineering and data cleaning. The first step in my mind is to
use the tokenized input data to train the model. This should allow the
model to learn more about the structure of the code, and less about line
changes.

Using Cregit, Professor German has tokenized the Linux and Zephyr kernels.
I will use this data to train my model, but first I need to think about
how to format the data.

Before now, I was using the following format (as detailed above):

```
### Instruction: (Commit message)
Bluetooth: A2DP: Fix NULL pointer references issue

### Input: Code before commit
a2dp->start_param.acp_stream_ep_id = stream->remote_ep == NULL ?
 		stream->remote_ep->sep.sep_info.id : stream->remote_ep_id;

### Response: Code diff of commit
-   a2dp->start_param.acp_stream_ep_id = stream->remote_ep == NULL ?
+   a2dp->start_param.acp_stream_ep_id = stream->remote_ep != NULL ?
```

Where the intruction is the commit message, the input is the code before
the commit, and the response is the diff of the commit.

But let's move to a more tokenized format:

```
### Instruction: (Commit message)
Bluetooth: A2DP: Fix NULL pointer references issue

### Input: Tokens before commit
name|acp_stream_ep_id
operator|=
name|stream
operator|->
name|remote_ep
operator|==
name|NULL
condition|?
name|stream
operator|->
name|remote_ep

### Response: Tokens diff of commit
-operator|==
+operator|!=
```

This gives context to the model about exactly what is changing. Now
adding plain english in the instruction, the model should be able to
learn more about the fixes relationship with the commit message:

```
### Instruction:
There is an issue in the following code. It relates to drivers: spi: litex: add missing include

add missing include of `soc.h`. Please fix this issue.

### Input:
Faulty tokenized code:
include|#
directive|include
file|<stdbool.h>
end_include
begin_comment
comment|/* Helper Functions */
end_comment
begin_function

### Response:
I corrected the issue in the code by changing the following tokens:
+begin_include
+include|#
+directive|include
+file|<soc.h>
+end_include
+
The issue was with: drivers: spi: litex: add missing include

add missing include of `soc.h`.
```

This bakes the commit message into the input data, and should allow the
model to learn more about the relationship between the commit message and
the code changes.

Obviously, nobody wants to tokenize their code before interacting with an
LLM, so I will need to bake this into the process somehow.

The resulting dataset using this strategy is available [here](./datasets/zephyr_tokenized.json).

### Week 5

Using the dataset which was created last week, I trained _"Zephllama"_ on 
~1000 tokenized commits. Let's take a looks at the results.

#### Cregit

I installed and configured cregit on both my Windows and MacOS systems,

- On Ubuntu 20 you need to manually allow installing an older version of libssl

The reason I could not just use my MacOS system:

- `unsloth` does not support MPS backend (Apple Silicon)
- `bitsandbytes` which is the alternative, also does not support MPS.

For this reason, loading a trained model onto Apple Silicon is not yet possible.

However, once properly installed, you can get output similiar to the following:

```
srcml example.cpp | srcml2token

-:-     begin_unit|revision:1.0.0;language:C++;cregit-version:0.0.1
-:-     begin_expr_stmt
1:1     name|ret
1:5     operator|=
1:7     name|gpio_pin_configure
1:25    argument_list|(
1:26    name|dev
1:29    argument_list|,
1:31    name|LED_PIN
1:38    argument_list|,
1:40    name|GPIO_INPUT
1:50    argument_list|)
1:51    expr_stmt|;
-:-     end_expr_stmt
-:-     begin_if_stmt
2:1     if|if
2:4     condition|(
2:5     name|ret
2:9     operator|!=
2:12    literal|0
2:13    condition|)
2:15    block|{
3:3     name|printk
3:9     argument_list|(
3:10    literal|"Failed to configure pin %d\n"
3:40    argument_list|,
3:42    name|LED_PIN
3:49    argument_list|)
3:50    expr_stmt|;
4:3     return|return;
5:1     block|}
-:-     end_if_stmt
-:-     end_unit
```

#### Preparing an example bug

In this example, `example.cpp` is a snippet of code:

```
ret = gpio_pin_configure(dev, LED_PIN, GPIO_INPUT);
if (ret != 0) {
  printk("Failed to configure pin %d\n", LED_PIN);
  return;
}
```

Which mimics Zephyr code, with one error:

- `GPIO_INPUT` should be `GPIO_OUTPUT`

Since I made this up, it should not be in the training data.

#### Preparing ask.py to handle tokenized code

By using the existing script in the following way:


     python ask.py "There is an error in the following code related to GPIO_INPUT" "Here is the faulty code: \n$(cat example.txt)"

We are matching the format of the model which was trained on ~1000 tokenized commits from Zephyr.

#### The response

After numerous tries with this model, I've seen 2 different responses.

NOTE: I removed line and column numbers for now.

```
<|begin_of_text|>Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
There is an error in the following code related to GPIO_INPUT

### Input:
Here is the faulty code:
begin_unit|revision:1.0.0;language:C++;cregit-version:0.0.1
begin_expr_stmt
name|ret
operator|=
name|gpio_pin_configure
argument_list|(
name|dev
argument_list|,
name|LED_PIN
argument_list|,
name|GPIO_INPUT
argument_list|)
expr_stmt|;
end_expr_stmt
begin_if_stmt
if|if
condition|(
name|ret
operator|!=
literal|0
condition|)
block|{
name|printk
argument_list|(
literal|"Failed to configure pin %d
"
argument_list|,
name|LED_PIN
argument_list|)
expr_stmt|;
return|return;
block|}
end_if_stmt
end_unit

### Response:
The error in the code was with: GPIO_INPUT

The correct code:
begin_unit|revision:1.0.0;language:C++;cregit-version:0.0.1
begin_expr_stmt
name|ret
operator|=
name|gpio_pin_configure
argument_list|(
name|dev
argument_list|,
name|LED_PIN
argument_list|,
name|GPIO_OUTPUT
argument_list|)
expr_stmt|;
end_expr_stmt
begin_if_stmt
if|if
condition|(
name|ret
operator|!=
literal|0
condition|)
block|{
name|printk
argument_list|(
literal
```

Or

```
### Response:
I corrected the error in the code by changing the following tokens:
-name|GPIO_INPUT
+name|GPIO_OUTPUT
The error was with: GPIO_INPUT
```

I also want to make sure I'm not giving it the answer, so let's change
the prompt around a few times:

```
### Instruction:
There is an error in the following code where my LED iisn't lighting up

...

### Response:
I corrected the error in the code by changing the following tokens:
-name|GPIO_INPUT
+name|GPIO_OUTPUT
The error was with: There is an error in the following code where my LED iisn't lighting up
```

```
### Instruction:
There is an error in the following, please fix the issue

### Input:
Here is the faulty tokenized code:
...

### Response:
I corrected the issue in the code by changing the following tokens:
+begin_comment
+comment|/* CONFIG_GPIO_PINTYPE_OUTPUT */
+end_comment
+
-name|GPIO_INPUT
+name|GPIO_OUTPUT
The issue was with: syntax: error: missing expression

begin_unit|revision:1.0.0;language:C++;cregit-version:0.0.1
begin_expr_stmt
name|ret
operator|=
name|gpio_pin_configure
argument_list|(
name|dev
argument_list|,
name|LED_PIN
argument_list|,
name|GPIO_INPUT
argument_list|)
```

We can see a few exciting things here:

- Zephllama responded in the tokenized output it was trained to,
- It fixed the actual bug in all my tests,
- It not only fixed the bug, but sometimes gave full context as well.

It's clear that this model learned better than the last, but it's
not perfect.

A few improvements for this model would be:

- If the model is producing a diff, it should include some context of
where that diff goes in the original code. 
- The output should be in a de-tokenized, readable format,
- The tokenization should take place in my script.

#### Moving forward

The prompt style should change again to follow:

Instruction: Describe code format, as much problem context as possible, and a fix format.

Input: The faulty code snippet.

Result: Describe a more specific solution statement, give full code context with the fix.

Since the tokenization can improve our learning, the pipeline might look something like:

Intruction:

- Pad with code formatting and response desires (ex. give me the fix in context).

Input:

- Run `srcml2token` on passed code

Result:

- Feature engineering: error location
    - Using `git diff` input `<START_ERROR>` `<END_ERROR>` tokens
- Feature engineering: error resolution
    - In between special tokens, make the fix
- Output readable code, requires an `undo-srcml2token`, or can be machine learned.

Let's take a look at how our example would look as training data:

```
I'm having trouble turning on the LED. What's wrong in my code?

ret = gpio_pin_configure(dev, LED_PIN, GPIO_INPUT);
if (ret != 0) {
  printk("Failed to configure pin %d\n", LED_PIN);
  return;
}
```

Converted to look like our training data:

```
### Instruction:
I'm having trouble turning on the LED. What's wrong in my code? Please fix the issue.

### Input:
Here is the faulty code:

ret = gpio_pin_configure(dev, LED_PIN, GPIO_INPUT);
if (ret != 0) {
  printk("Failed to configure pin %d\n", LED_PIN);
  return;
}

### Tokenized:
Here is the faulty code which has been tokenized:

begin_unit|language:C++
begin_expr_stmt
name|ret
operator|=
name|gpio_pin_configure
argument_list|(
name|dev
argument_list|,
name|LED_PIN
argument_list|,
name|GPIO_INPUT
argument_list|)
expr_stmt|;
end_expr_stmt
begin_if_stmt
if|if
condition|(
name|ret
operator|!=
literal|0
condition|)
block|{
name|printk
argument_list|(
literal|"Failed to configure pin %d"
argument_list|,
name|LED_PIN
argument_list|)
expr_stmt|;
return|return;
block|}
end_if_stmt
end_unit

### Error location:
I have identified the issue in the tokenized code. I have placed a <START_ERROR>
before the problematic tokens and a <END_ERROR> after the problematic tokens:

begin_unit|language:C++
begin_expr_stmt
name|ret
operator|=
name|gpio_pin_configure
argument_list|(
name|dev
argument_list|,
name|LED_PIN
argument_list|,
<START_ERROR>
name|GPIO_INPUT
<END_ERROR>
argument_list|)
expr_stmt|;
end_expr_stmt
begin_if_stmt
if|if
condition|(
name|ret
operator|!=
literal|0
condition|)
block|{
name|printk
argument_list|(
literal|"Failed to configure pin %d"
argument_list|,
name|LED_PIN
argument_list|)
expr_stmt|;
return|return;
block|}
end_if_stmt
end_unit

### Error correction:
Here is the code with the issue corrected:

begin_unit|language:C++
begin_expr_stmt
name|ret
operator|=
name|gpio_pin_configure
argument_list|(
name|dev
argument_list|,
name|LED_PIN
argument_list|,
name|GPIO_OUTPUT
argument_list|)
expr_stmt|;
end_expr_stmt
begin_if_stmt
if|if
condition|(
name|ret
operator|!=
literal|0
condition|)
block|{
name|printk
argument_list|(
literal|"Failed to configure pin %d"
argument_list|,
name|LED_PIN
argument_list|)
expr_stmt|;
return|return;
block|}
end_if_stmt
end_unit

### Response:
I have identified the issue in the code you provided:

// This is where the error is
ret = gpio_pin_configure(dev, LED_PIN, GPIO_INPUT);
if (ret != 0) {
  printk("Failed to configure pin %d\n", LED_PIN);
  return;
}

The issue is with the GPIO_INPUT name, here is the
the code with this issue corrected:

// Corrcted the error
ret = gpio_pin_configure(dev, LED_PIN, GPIO_OUTPUT);
if (ret != 0) {
  printk("Failed to configure pin %d\n", LED_PIN);
  return;
}
```

So, generalazing to Zephyr, let's try a full machine learning approach:

- Micro commits,
- That mention "fix", "bug", "correct", etc.
- Tranformed into above format where
    - Code is tokenized
    - The special "error tokens" are inserted based on git diff
    - Tokenized fix is generated
    - Original code snippet with comment inserted
    - Fixed code snippet with comment inserted

Using a combination of:

- Original repository
- Repository which has been "cregit-ified"
- srcml2token

This should be possible for both Zephyr and Linux kernels.

This combines everything this project has learned thus far into one model.

### Week 6

- I updated the `promptify.sh` script to include the new format for tokenized code utilizing `srcml2token`.
- I have created a new dataset using the above format, which is available [here](./datasets/zephyr_locations.json).
- I wrote a Python script which displays the the prompts as showed above, and can be found [here](./show.py).
- I attempted to train a new model on this dataset, but ran out of credits on Google Colab.
- By using a new account I should be able to train the model and evaluate it.

### Week 7

New full machine learning approach has been trained. Let's see how it does.

#### Initial results

```
### Instruction:
Can you fix the issue in this python code, i think the problem is in logging in

### Input:
def login():
        return True

### Tokenized:
Here is the tokenized version of the input:

begin_unit|revision:1.0.0;language:C++;cregit-version:0.0.1
begin_function
name|login
parameter_list|(
name|void
parameter_list|)
block|{
return|return
literal|True
return|;
block|}
end_function
end_unit
```

Obviously I gave a model trained on C++ a Python snippet, but the model
actually did a really good job at tokenizing an input it has deifnitely never
seen before.

Let's see how it does on some actual C++ code. I'm starting with a
fairly trivial error based on kernel style code:

```
### Instruction:
Can you fix the issue in my code, I think the problem is in the sensor loop.

### Input:
Here is the faulty code:

void sensor_reading_thread(void)
{
    int temperature = -1;

    while (temperature >= 0) {
        // Reading temperature
        temperature = read_sensor();

        // Sleep for 1 second
        k_sleep(K_SECONDS(1));
    }
}

...

### Error location:
I have identified the issue in the tokenized code. I have placed a <START_ERROR> before the problematic tokens and a <END_ERROR> after the problematic tokens:

...
while|while
condition|(
name|temperature
<START_ERROR>
operator|>
literal|0
<END_ERROR>
condition|)
block|{
...
```

I've truncated this, but this shows that the model was able to indentify
the while condition is likely the issue here (which I agree with).

It was not able to successfully fix this issue however.

Another example:

```
### Instruction:
I'm having issues in the following code in relation to the LED handle. What's wrong? Please fix the issue

### Input:
Here is the faulty code:

void toggle_led()
{
    const struct device *dev = device_get_binding("GPIO_0");
    if (!dev) {
        printk("Failed to bind to GPIO device");
        return;
    }

    gpio_pin_configure(dev, LED_PIN, GPIO_OUTPUT);

    while (true) {
        gpio_pin_toggle(dev, LED_PIN);
        k_sleep(K_MSEC(SLEEP_TIME_MS));
    }
}
K_THREAD_DEFINE(led_thread_id, 1024, toggle_led, NULL, NULL, NULL, 7, 0, 0);

...

### Response:
The issue was with: the LED handle. What was the issue? Here is the corrected version:

void toggle_led()
{
    const struct device *dev = device_get_binding("GPIO_0");
    if (\!dev) {
        printk("Failed to bind to GPIO device");
        return;
    }

    if (dev == NULL) {
        printk("Failed to get device");
        return;
    }

    gpio_pin_configure(dev, LED_PIN, GPIO_OUTPUT);

    while (true) {
        gpio_pin_toggle(dev, LED_PIN);
        k_sleep(K_MSEC(SLEEP_TIME_MS));
    }
}
K_THREAD_DEFINE(led_thread_id, 1024, toggle_led, NULL, NULL, NULL, 7, 0, 0);<|end_of_text|>
```

#### Tokenization

Let's analyze how good llama actually was at tokenizing.

Diff of srcml2token vs llama for following code:

```
void toggle_led()
{
    const struct device *dev = device_get_binding("GPIO_0");
    if (!dev) {
        printk("Failed to bind to GPIO device");
        return;
    }

    gpio_pin_configure(dev, LED_PIN, GPIO_OUTPUT);

    while (true) {
        gpio_pin_toggle(dev, LED_PIN);
        k_sleep(K_MSEC(SLEEP_TIME_MS));
    }
}
K_THREAD_DEFINE(led_thread_id, 1024, toggle_led, NULL, NULL, NULL, 7, 0, 0);
```

```
61,63d60
< block|}
< end_function
< begin_expr_stmt
85c82
< end_expr_stmt
---
> end_function
```

Basically, llama missed the `begin_expr_stmt` at the end, it's possible it never saw this in training.

All things considered I'm impressed how well llama was at tokenizing.

#### Opinion

While llama learned tokenizing very well, and it's fairly good at recognizing the error
location, it's proposed fixes are nothing special.

### Week 8

Started report, investigated evaluation strategy

### Week 9

Added draft report to this repository. See [the report]() for progress there.

Updated `promptify.sh` structure to target the follwoing commits:

Commits which:
- Only change one file,
- Only have a full context length of 40 tokens,
- Match the file mask (ex. `.c` or `.h`)
- Commit message contains a bug-related word (ex. "bug" "fix" "error" "issue" "patch", etc.)

It also now excludes a number of random commits which are saved
to a different file to be used as evaluation commits. The random
selection uses a `shuf` command to remove any bias of me choosing the
commits.

I also added some usage instuctions for all scripts in this README.

See [the training set](./datasets/zephyr_filtered.json) and the [evaluation set](./datasets/zephyr_filtered_eval.json).

Using the new and more specific dataset, I did a quick training run on codeLLAMA
which is a model tuned specifically for code. I thought it may yield better results.

The results

```
### Error correction:
Here is the faulty code:

Here is the faulty code:

                                end_of_send = 0;
                                continue;
                        } else {
                                memcpy(send_buf + end_of_send,
                                        data + end_of_data,
                                        remaining_len);
                                end_of_send += remaining_len;
                                remaining_len = 0;
                        }

### Error explanation:
Here is the faulty code:

Here is the faulty code:

                                end_of_send = 0;
                                continue;
                        } else {
                                strncpy(send_buf + end_of_send,
                                        data + end_of_data,
                                        remaining_len);
                                end_of_send += remaining_len;
```

We can see that this is not even picking up the tokenization, nor 
giving meaningful output. It's possible I would need to re-egineer my
prompt design to allow this model to learn anything from my data. For this
reason I am going to be focusing on LLAMA 3.x from now on instead.

Using the same dataset on LLAMA 3.2 3B:

```
### Input:
Here is the faulty code:


                                end_of_send = 0;
                                continue;
                        } else {
                                strncpy(send_buf + end_of_send,
                                        data + end_of_data,
                                        remaining_len);
                                end_of_send += remaining_len;
                                remaining_len = 0;
                        }

### Tokenized:
Here is the faulty code which has been tokenized:

begin_expr_stmt
name|end_of_send
operator|=
literal|0
operator|;
end_expr_stmt
begin_expr_stmt
name|continue
end_expr_stmt
begin_if_stmt
if|else
condition|(
name|end_of_send
operator|!=
name|end_of_data
condition|)
block|{
name|strncpy
argument_list|(
name|send_buf
operator|+
name|end_of_send
argument_list|,
name|data
operator|+
name|end_of_data
argument_list|,
name|remaining_len
argument_list|)
name|end_of_send
operator|+
name|remaining_len
operator|=
literal|0
block|;
end_if_stmt
begin_expr_stmt
name|end_of_send
operator|+
name|remaining_len
operator|=
literal|0
end_expr_stmt

### Error location:
I have identified the issue in the tokenized code. I have placed a <START_ERROR> before the problematic tokens and a <END_ERROR> after the problematic tokens:

begin_expr_stmt
name|end_of_send
operator|=
literal|0
operator|;
end_expr_stmt
<START_ERROR>
begin_expr_stmt
name|continue
end_expr_stmt
begin_if_stmt
if|else
condition|(
name|end_of_send
operator|!=
name|end_of_data
condition|)
block|{
name|strncpy
argument_list|(
name|send_buf
operator|+
name|end_of_send
argument_list|,
name|data
operator|+
name|end_of_data
argument_list|,
name|remaining_len
argument_list|)
name|end_of_send
operator|+
name|remaining_len
operator|=
literal|0
block|;
end_if_stmt
<END_ERROR>
begin_expr_stmt
name|end_of_send
operator|+
name|remaining_len
operator|=
literal|0
end_expr_stmt

### Error correction:
Here is the tokenized code with the issue corrected:

begin_expr_stmt
name|end_of_send
operator|=
literal|0
operator|;
end_expr_stmt
begin_expr_stmt
name|continue
end_expr_stmt
begin_if_stmt
if|else
condition|(
name|end_of_send
operator|!=
name|end_of_data
condition|)
block|{
name|memcpy
argument_list|(
name|send_buf
operator|+
name|end_of_send
argument_list|,
name|data
operator|+
name|end_of_data
argument_list|,
name|remaining_len
argument_list|)
name|end_of_send
operator|+
name|remaining_len
operator|=
literal|0
block|;
end_if_stmt
begin_expr_stmt
name|end_of_send
operator|+
name|remaining_len
operator|=
literal|0
end_expr_stmt

### Response:
I corrected the issue in the code you provided:

...

Here is the faulty code:

                                end_of_send = 0;
                                continue;
                        } else {
                                strncpy(send_buf + end_of_send,
                                        data + end_of_data,
                                        remaining_len);
                                end_of_send += remaining_len;
                                remaining_len = 0;
                        }

...

Here is the faulty code which has been corrected:

                                end_of_send = 0;
                                continue;
                        } else {
                                memcpy(send_buf + end_of_send,
                                        data + end_of_data,
                                        remaining_len);
                                end_of_send += remaining_len;
                                remaining_len = 0;
                        }<|end_of_text|>
```

This looks a lot better, let's put it through the evaluation.

```
- 🟨 Did it tokenize the code correctly?

While the diff will show some variance, the LLM inferred the
if condition to write a more complete tokenization. The general
structure of the tokens looks reasonable.

- 🟨 Did it place the `<START_ERROR>` `<END_ERROR>` tokens around issue?

It did place the tokens around the error, but not as specifically as it could have.

- ✅ Did it apply a fix which is similiar to the expected result?

The fix is the same as the expected results.

- ❌ Did it give a meaningful explanation about the change?

This is not yet baked into training data.
```
