# Ollama-Vision

A PowerShell script that uses Ollama and LM Studio models (Llava, Gemma, Llama etc.) to rename files by their contents intelligently
This set of scripts was created as I had a dislike for the 20k images I have that were just named DCS00001 DCS00002 DCS00003 and so on. After running this I now have 2006-02-13_00-29-44_People_Nightclub_Laughing_RedDrink_020.jpg 2010-06-30_13-40-56_airfield_planes_cloudy_Photo_0014.jpg

## Usage

You need to have [Ollama](https://ollama.com/download) and at least one LLM (Llava, Gemma, Llama etc.) installed on your system.




## Ollama Usage

Ollama is the default provider so you don't have to do anything other than setup ollama and 2 models totalling 10GB.

1. Install [Ollama](https://ollama.com/download)
2. Setup the models by opening the command prompt and running the following commands 
```bash
ollama run llama3.2-vision
ollama run gemma2
```
3. Open a PowerShell command promt and navigate to the root of your images (Always do a test run on some images you have copied)
4. Run Run_BatchProcessing.ps1


## Params

Currently, all config values you can find in Config.ps1. 




## Contribution

Feel free to contribute. Open a new [issue](https://github.com/ArMaTeC/Ollama-Vision/issues), or make a [pull request](https://github.com/ArMaTeC/Ollama-Vision/pulls).

## License

[GPL-3.0](https://github.com/ArMaTeC/Ollama-Vision/blob/main/license)
