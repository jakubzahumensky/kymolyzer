# Author information:

-   e-mail: <jakub.zahumensky@iem.cas.cz>
-   e-mail: <jakub.zahumensky@gmail.com>
-   GitHub: <https://github.com/jakubzahumensky/kymolyzer>
-   Czech Academy of Sciences, Institute of Experimental Medicine
    -   Department of Functional Organisation of Biomembranes

# Summary

This Fiji macro uses microscopy time-series calculates kymograms and
analyzes them. The analysis includes filtering of main directions and
calculation of several quantification parameters, such as speed of
particles (high-intensity foci), their lifetime, etc. It also analyzes
the coupling (colocalization) of signals from two channels, when
applicable.

------------------------------------------------------------------------

# Workflow

It is strongly recommended that raw microscopy images are corrected for
drift and bleaching before defining regions of interest (ROIs), for
example using our [**Correct and
project.ijm**](https://github.com/jakubzahumensky/microscopy_analysis/blob/main/Fiji%20macros/0.%20correct_and_project.ijm)
macro, which also provides an option for different types of Z
projections. Working with maximum intensity projections can be helpful
when working with images with low signal. It also facilitates quick
assessment of drift correction.

The required data structure and use of the code is described in detail
in [Zahumensky & Malinsky,
2024](https://doi.org/10.1093/biomethods/bpae075).

*available processing options (modules):* Select the appropriate
operation from the list below. The available operations need to be run
in the order in which they are listed. The macro will fail otherwise.
After an operation is finished, the next one is preselected
automatically.

## 1. Draw ROIs

The calculation of kymograms requires ROIs. These can be prepared either
automatically, using the approach described
[**here**](https://doi.org/10.1093/biomethods/bpae075), or manually
using the provided option in this macro. Draw ROIs Manually create ROIs
for your images. Images are displayed one at a time, together with a
prompt and details on how to proceed. The ROIs can be defined using
e.g. Cellpose, as described in \[1\], or in any other way, but they need
to be named and organized as described in \[1\]. They can also be
defined manually using the *Draw ROIs* option of this macro, which
respects these requirements.

## 2. Create kymograms

Create kymograms Create kymograms from defined ROIs. Error is displayed
if no ROIs are defined.

*Note: direct import of kymograms created externally is currently not
supported*

## 3. Display kymograms

Display kymograms Images in the specified folder are displayed
one-by-one, together with kymograms for each cell (defined ROI). If
direction-filtered images of kymograms and individual traces have been
already calculated, they can be displayed as well. In this case, the
regular kymograms are displayed as well, to facilitate comparison.

## 4. Filter kymograms

Filter kymograms Kymograms are filtered using Fourier transformations
into dominant directions: backward (bwd), forward (fwd), static (stat).
These are then thresholded and binarized to extract prominent individual
traces.

## 5. Analyze kymograms

Analyze kymograms Kymograms are quantified. Results are saved in a csv
table file, which is reffered to as *Results table*. For detailed
description of the parameters reported in the Results table see the
[Results table legend](results_table_legend.md).

## 6. Process the *Results table*

The Results table can be processed using our custom [*R
script*](https://github.com/jakubzahumensky/microscopy_analysis/tree/main/processing%20in%20R)
developed previously.

# Dialog windows

## Directory

Specify the directory where you want *Fiji* to start looking for folders
with images. The macro works *recursively*, i.e., it looks into all
*sub*folders. All folders with names *ending* with the word *data* are
processed. All other folders are ignored.

## Image type

Select if your images represent *transversal* (also called *equatorial*)
or *tangential* sections of the cells.

## Subset

If used, only images with filenames containing specified *string* (i.e.,
group of characters and/or numbers) will be processed. This option can
be used to selectively process images of a specific strain, condition,
etc. Leave empty to process all images in specified directory (and its
subdirectories).

## Channel(s)

Specify image channel(s) to be processed. Use comma(s) to specify
multiple channels or a dash to specify a range.

## Channel display

Specify LUTs (lookup tables) image channel(s) to be used for display of
images. The calculated kymograms are saved using these. Note that the
LUT names need to correspond with the names used by Fiji.

# Copyright and Non-Liability Disclaimer

The codes are available under the [CC BY-NC
licence](https://creativecommons.org/licenses/by-nc/4.0/). The users are
free to distribute, remix, adapt, and build upon the material in any
medium or format for non-commercial purposes. Attribution to the creator
is required.

The software is provided “as is”, without warranty of any kind, express
or implied, including but not limited to the warranties of
merchantability, fitness for a particular purpose and noninfringement.
In no event shall the authors or copyright holders be liable for any
claim, damages or other liability, whether in an action of contract,
tort or otherwise, arising from, out of or in connection with the
software or the use or other dealings in the software.

# Citation

When using this work, please cite the authors:

-   GitHub: <https://github.com/jakubzahumensky/kymolyzer>
-   Zenodo: <https://doi.org/10.5281/zenodo.15650134>
-   Related work: Zahumensky J., Malinsky J. Live cell fluorescence
    microscopy—an end-to-end workflow for high-throughput image and data
    analysis. *Biology Methods and Protocols*, Volume 9, Issue 1, 2024,
    bpae075; doi: <https://doi.org/10.1093/biomethods/bpae075>
