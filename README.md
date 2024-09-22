# pengullama

CSC 499: Hnours Project

This repository contains work completed as part of my honours project.

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

## Progress

Below is the week-by-week summary of progress towards this projects goals.

### Week 1

Set up proposed devleopment environment in order to train llama:

    - RTX 2060 Super
    - WSL
    - Unsloth

Using unsloth, trained llama 3.1 8B on one "fake" data point.

For more details see [this notebook](./notebooks/week_1.ipynb).

### Week 2

Wrote a script to format git histories to conform to Aplaca prompt standard.

For more details see [the script](./promptify.sh).

Attempted to train llama 3.1 8B on latest 100 commits of Zephyr, but quickly
ran out of memory when adding any more than 1 data point.

Ported my code to Google Colab, which provides a Tesla T4 for free.

Uploaded resulting model to my [Hugging Face](https://huggingface.co/wrighted/zephllama).
