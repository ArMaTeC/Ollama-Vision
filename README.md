# Ollama-Vision

A powershell script that uses Ollama and LM Studio models (Llava, Gemma, Llama etc.) to intelligently rename files by their contents


## Usage

You need to have [Ollama](https://ollama.com/download) and at least one LLM (Llava, Gemma, Llama etc.) installed on your system.


```

## Ollama Usage

Ollama is the default provider so you don't have to do anything other then setup ollama and 2 models totalling 10GB.

1. Install [Ollama](https://ollama.com/download)
2. Setup the models by opens command prompt and running the following commands 
```bash
ollama run llama3.2-vision
ollama run gemma2
```
3. Open a powershell command promt and navigate to the root of your images (Always do a test run on some images you have copied)
4. Run Run_BatchProcessing.ps1
```

## Params

Currenlty all config values you can find in Config.ps1. 

```bash

```


## Contribution

Feel free to contribute. Open a new [issue](https://github.com/ArMaTeC/Ollama-Vision/issues), or make a [pull request](https://github.com/ArMaTeC/Ollama-Vision/pulls).

## License

[GPL-3.0](https://github.com/ArMaTeC/Ollama-Vision/blob/main/license)