# **The *Results table***

The *Kymolyzer* macro outputs a single comma-separated values (CSV) table containing data from all analyzed cells across all experiments. The table begins with a header followed by rows of quantitative results for each individual cell (ROI), organized into clearly labeled columns. Each column is explained below.

---

## **Table header**

Each line of the header starts with a pound sign (`#`) and is automatically ignored by *R* scripts (use of our [R scripts](https://github.com/jakubzahumensky/microscopy_analysis/tree/main/processing%20in%20R) is recommended).

-   **Macro name** – name of the macro used
-   **Macro version** – version of *Kymolyzer* used (indicated in the macro filename and internally as the `version` variable)
-   **Date and time** – when the macro was executed (run), in the YYYY-MM-DD HH:MM:SS format; the timestamp in the output filename corresponds to the end of the macro run
-   **Image type** – indicates whether quantification was performed on transversal (equatorial) or tangential images
-   **Channel** – fluorescence channel used for quantification (also noted in the file name)
-   **Abbreviations** – defines commonly used short forms in column headers:
    -   *fwd* – forward
    -   *bwd* – backward
    -   *stat* – static
    -   *T* – lifetime
    -   *v* – speed

---

## **Column definitions**

Each row corresponds to a single analyzed cell (ROI) and contains the following parameters, grouped by origin:

---

### **From folder structure**

-   **exp_code** – experiment identifier (accession code), extracted from the folder three levels above the data folder
-   **BR_date** - date of biological replicate; extracted from the name of the folder 2 levels above the data folder (first 6 characters)

*for details on data structure consult Fig. 6 in [Zahumensky & Malinsky, 2024](https://doi.org/10.1093/biomethods/bpae075)*

---

### **From file name**

These labels are defined by the user via the *Naming scheme* input in the *Kymolyzer* dialog, in the *Analyze kymograms* option. The number of comma-separated fields must match the structure of the filenames.

-   **strain** – yeast strain
-   **medium** – cultivation medium
-   **time** – cultivation time
-   **condition** – treatment condition (e.g., control, heat shock, drug)
-   **frame** – frame identifier (e.g., different images from the same sample)

---

### **From image analysis**

-   **mean_background** – average background intensity; subtracted from all intensity measurements
-   **frame_interval** – time between consecutive frames (in seconds); extracted from metadata or entered manually if missing — *ensure accuracy for correct speed/lifetime quantification!*
-   **cell_no** – ROI identifier, matching the number shown in Fiji's ROI Manager

---

### **Quantified dynamics (by direction)**

-   **traces_fwd/bwd/stat** – number of traces in the forward (right), backward (left), or static direction
-   **v_fwd/bwd/stat [nm/s]** – average speed of traces in each direction 
-   **T_fwd/bwd/stat [s]** – average lifetime of traces in each direction (i.e., duration between appearance and disappearance of a focus)
-   **mean_v [nm/s]** – weighted average of absolute speeds across all directions
-   **mean_T [s]** – weighted average of lifetimes across all directions
-   **mobile_fraction [%]** – estimated fraction of mobile signal relative to total signal

*note that only traces that both start and end within the kymogram, or span it entirely, are taken into account during quantification*

---

### **Coupled signal analysis (based on colocalization with second channel)**

-   **coupled_v_fwd/bwd/stat [nm/s]** – average speed of coupled (colocalized) foci in each direction
-   **coupled_T_fwd/bwd/stat [s]** – average lifetime of coupled foci in each direction
-   **coupled_fwd/bwd/stat_fraction [%]** – proportion of traces in each direction that colocalize with traces in the second channel
-   **coupled_mean_v [nm/s]** – weighted average speed (absolute) of all coupled foci
-   **coupled_mean_T [s]** – weighted average lifetime of all coupled foci
