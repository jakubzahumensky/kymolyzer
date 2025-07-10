# Kymolyzer
## Automated analysis of movement in microscopy data - from images to numbers and plots

This repository contains a custom **Fiji (ImageJ)** macro developed for automatic analysis of movement in microscopy images. The macro creates [kymograms (also called kymographs)](https://imagej.net/tutorials/generate-and-exploit-kymographs), filters them into main directions (forward, backward, static; approach based on [Mangeol et al., 2016](https://doi.org/10.1091/mbc.e15-06-0404)) and quantifies the numbers of moving foci, their speeds in different directions, and their lifetimes. For multichannel images, the macro also analyzes the coupling (colocalization) moving signal in the two channels and quantifies it.

The required data structure and use of the code is described in detail in [Zahumensky & Malinsky, 2024](https://doi.org/10.1093/biomethods/bpae075).

The Results table can be processed using our custom [R script](https://github.com/jakubzahumensky/microscopy_analysis/tree/main/processing%20in%20R) developed previously. For detailed description of the parameters reported in the Results table see the [Results table legend](results_table_legend.md).

---

## Segmentation of cells/objects:

[**Cellpose 2.0**](https://www.cellpose.org/) ([Stringer et al., 2021](https://www.nature.com/articles/s41592-020-01018-x)):

-   [Installation instructions](https://github.com/MouseLand/cellpose/blob/main/README.md)

-   requires [Python](https://www.python.org/downloads/) and [Anaconda](https://www.anaconda.com/download); installation instructions can be found on the [Cellpose Readme website](https://github.com/MouseLand/cellpose/blob/main/README.md)

---

## Copyright

The codes are available under the CC BY-NC licence. The users are free to distribute, remix, adapt, and build upon the material in any medium or format for non-commercial purposes. Attribution to the creator is required.

## Non-Liability Disclaimer

The software is provided “as is”, without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.

---

## Acknowledgement

Development of this software was supported by the MEYS CR (LM2023050 Czech-BioImaging).

---

## Citation

If you use Kymolyzer in your research, please cite the Zenodo DOI: [10.5281/zenodo.15853597](https://doi.org/10.5281/zenodo.15853597)

Related work:\
**Jakub Zahumensky & Jan Malinsky: Live cell fluorescence microscopy—an end-to-end workflow for high-throughput image and data analysis**\
*Biology Methods and Protocols*, Volume 9, Issue 1, 2024, bpae075\
doi: <https://doi.org/10.1093/biomethods/bpae075>
