/***************************************************************************************************************************************
 * BASIC MACRO INFORMATION
 *
 * title: "Kymolyzer"
 * author: Jakub Zahumensky
 * - e-mail: jakub.zahumensky@iem.cas.cz
 * - e-mail: jakub.zahumensky@gmail.com
 * - GitHub: https://github.com/jakubzahumensky
 * - Department of Functional Organisation of Biomembranes
 * - Institute of Experimental Medicine CAS
 * - citation: https://doi.org/10.1093/biomethods/bpae075
 *
 * Summary:
 *  This macro takes microscopy time-series corrected for drift and/or bleaching calculates kymograms and analyzes them.
 *  The analysis includes filtering of main directions and calculation of several quantification parameters, such as speed of particles,
 *  variation of signal etc. The calculation of kymograms requires ROIs. These can be prepared either automatically, using the approach
 *  described in https://doi.org/10.1093/biomethods/bpae075, or manually using the provided option in this macro.
 ***************************************************************************************************************************************/

macro_name = "Kymolyzer";
version = "1.0";
publication = "Zahumensky & Malinsky, 2024; doi: 10.1093/biomethods/bpae075";
GitHub_microscopy_analysis = "https://github.com/jakubzahumensky/microscopy_analysis";
GitHub_kymolyzer = "https://github.com/jakubzahumensky/kymolyzer";

/* For testing, uncomment the "test = true;" line (i.e., delete the "//").
 * -> batch mode does not start, so all intermediary images are shown
 * -> only a small number of ROIs is used/analyzed
 */
test = false;
//test = true;
last_ROI_test = 4;
if (test == false)
	setBatchMode(true);

/* definitions of constants used in the macro below */
extension_list = newArray("czi", "oif", "lif", "tif", "vsi"); // only files with these extensions will be processed, add your favourite one if it's missing
process_choices = newArray("Draw ROIs", "Create kymograms", "Display kymograms", "Filter kymograms", "Analyze kymograms", "EXIT");
filters = newArray("forward", "backward", "static");
interpolation = newArray("None","Bilinear");
RoiSet_suffix = "-RoiSet.zip";
images_without_ROIs_list = "images_without_ROIs.csv";
images_without_kymograms_list = "images_without_kymograms.csv";
//LUTs_filtered = newArray("Red", "Green", "Blue");
LUTs_filtered = newArray("Magenta", "Cyan", "Yellow");
image_types = newArray("transversal", "tangential");
boolean = newArray("yes", "no");

/***************************************************************************************************************************************/
dir_kymogram_source_data = "data";
initial_folder = "";
default_naming_scheme = "strain,medium,time,condition,frame";
//default_naming_scheme = "strain,colony,imaging,experiment,laser,frame";
/***************************************************************************************************************************************/

//LUTs_string = "Magenta, Cyan";
LUTs_string = "Magenta, Green";
channels_string = "1, 2";

/* definitions of global variables used in the macro below */
var naming_scheme = "";
var experiment_scheme = "";
var subset = "";
var image_type = "transversal";

var file = "";
var dir_ROIs = "";
var dir_kymograms_main = "";
var dir_kymograms_image = "";
var dir_kymograms_image_raw = "";
var dir_kymograms_image_filtered = "";
var channels_to_analyze = newArray();
var channels = newArray();
var channel_sum = 0;
var current_channel = "";
var frame_interval_global = 0;

var image_width = 0;
var image_height = 0;
var image_channels = 1;

var kymogram_list = "";
var process = "";
var process_ID = -1;
var LUTs = newArray(3);

var pixelWidth = 0;
var frame_interval = 0;

var images_without_kymograms_array = newArray();
var temporary_results_file = "";
var processed_images_file = "";
var analyze_overlap = false;
var just_started = true;
var continue_analysis = false;
var column_names_printed = newArray(0, 0, 0, 0, 0);
var background = 0;


/****************************************************************************************************************************************************/
/* The macro is started by calling the initialDialogwindow function, using the initial_folder as the default folder to be analyzed. */
run("Set Measurements...", "area mean min integrated redirect=None decimal=3");
initialDialogWindow(initial_folder);


/* ***************************************************************************************************************************************************/
/* INITIAL DIALOG WINDOW TO TAKE USER INPUT
 *
 * Display the initial dialog window that prompts the user to specify the folder to be processed/analyzed,
 * and to select a process: Draw ROIs, Create kymograms, Display kymograms, Filter kymograms or Analyze kymograms.
 * This window is opened again after the specified process is finished and the next one is automatically preselected.
 */
function initialDialogWindow(specified_folder){
	closeAllWindows();
	help_message = "<html>"
		+ "<center><b>" + macro_name + " " + version + "</b></center>"
		+ "<center><i>source: " + GitHub_kymolyzer + "</i></center><br>"

		+ "It is strongly recommended that the raw images are corrected for drift and bleaching before defining regions of interest (ROIs), "
		+ "for example using the <i>Correct and project.ijm</i> [2] macro, which also provides an option for different types of Z projections. "
		+ "Working with maximum/summary intensity projections can be helpful when working with images with low signal. "
		+ "It also facilitates quick assessment of drift correction. "
		+ "The ROIs can be defined using e.g. Cellpose, as described in [1], or in any other way, but they need to be named and organized as described in [1]. "
		+ "They can also be defined manually using the <i>Draw ROIs</i> option of this macro, which respects these requirements. <br><br>"

		+ "<b>Directory</b><br>"
		+ "Specify the directory where you want <i>Fiji</i> to start looking for folders with images. The macro works <i>recursively</i>, i.e., it looks into all <i>sub</i>folders. "
		+ "All folders with names <i>ending</i> with the word \"<i>data</i>\" are processed. All other folders are ignored. <br><br>"

		+ "<b>Image type</b><br>"
		+ "Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells. <br><br>"

		+ "<b>Subset</b><br>"
		+ "If used, only images with filenames containing specified <i>string</i> (i.e., group of characters and/or numbers) will be processed. "
		+ "This option can be used to selectively process images of a specific strain, condition, etc. "
		+ "Leave empty to process all images in specified directory (and its subdirectories). <br><br>"

		+ "<b>Channel(s)</b><br>"
		+ "Specify image channel(s) to be processed. Use comma(s) to specify multiple channels or a dash to specify a range. <br><br>"

		+ "<b>Channel display</b><br>"
		+ "Specify LUTs (lookup tables) image channel(s) to be used for display of images. The calculated kymograms are saved using these. "
		+ "Note that the LUT names need to correspond with the names used by Fiji. <br><br>"

		+ "<br><center><b><i>available processing options:</i></b></center><br>"
		+ "Select the appropriate operation from the list below. "
		+ "The available operations need to be run in the order in which they are listed. The macro will fail otherwise. "
		+ "After an operation is finished, the next one is preselected automatically. <br><br>"

		+ "<b>Draw ROIs</b><br>"
		+ "Manually create ROIs for your images. Images are displayed one at a time, together with a prompt and details on how to proceed. <br><br>"

		+ "<b>Create kymograms</b><br>"
		+ "Create kymograms from defined ROIs. Error is displayed if no ROIs are defined. <br><br>"

		+ "<b>Display kymograms</b><br>"
		+ "Images in the specified folder are displayed one-by-one, together with kymograms for each cell (defined ROI). "
		+ "If direction-filtered images of kymograms and individual traces have been already calculated, they can be displayed as well. "
		+ "In this case, the regular kymograms are displayed as well, to facilitate comparison. <br><br>"

		+ "<b>Filter kymograms</b><br>"
		+ "Kymograms are filtered using Fourier transformations into dominant directions: backward (bwd), forward (fwd), static (stat). "
		+ "These are then thresholded and binarized to extract prominent individual traces. <br><br>"

		+ "<b>Analyze kymograms</b><br>"
		+ "Kymograms are quantified. Results are saved in a csv file that can be further processed using <i>R scripts</i> published previously [1, 2]. "
		+ "For details on the quantified parameters reported in the Results table, consult the dedicated pdf file. <br><br>"

		+ "<b>References:</b><br>"
		+ "[1] " + publication + " <br>"
		+ "[2] " + GitHub_microscopy_analysis + " <br>"
		+ "</html>";
	Dialog.createNonBlocking("Kymolyzer");
		Dialog.addDirectory("Directory:", specified_folder);
		Dialog.addChoice("Image type:", image_types, image_type);
		Dialog.addString("Subset (optional):", "");
		Dialog.addString("Channels:", channels_string, 5);
		Dialog.addString("Channel display:", LUTs_string, 15);
		Dialog.addChoice("Select an operation:", process_choices, process_choices[process_ID + 1]);
//		Dialog.addChoice("Select an operation:", process_choices, process_choices[2]);
		Dialog.addHelp(help_message);
		Dialog.show();
		specified_folder = fixFolderInput(Dialog.getString());
		image_type = Dialog.getChoice();
		subset = Dialog.getString(); // global variable
		channels_string = Dialog.getString();
		channels = sortIDs(channels_string); // global variable
		LUTs_string = Dialog.getString();
		LUTs = sortLUTs(LUTs_string); // global variable
		process = Dialog.getChoice(); // global variable

	dir_master = specified_folder; // specified_folder into which Results summary is saved; it is the same specified_folder as is used by the user as the starting point
	process_ID = getArrayIndex(process_choices, process); // get index of seelcted process (enables automatic preselection of subsequent step in the dialog window)

	processFolder(specified_folder, process); // process all files in all folders recursively
	cleanUp();
	initialDialogWindow(specified_folder);
}

/* Convert backslash to slash in the folder path, append a slash at the end.
 * If analysis is run from within the data folder, move one level up.
 * These fixes are requird for the macro to work properly.
 */
function fixFolderInput(folder_input){
	folder_fixed = replace(folder_input, "\\", "/");
	if (!endsWith(folder_fixed, "/"))
		folder_fixed = folder_fixed + "/";
	if (indexOf(File.getName(folder_input), "data") == 0)
		folder_fixed = File.getParent(folder_fixed) + "/";
	return folder_fixed;
}

/* Remove empty spaces, split into an array and sort LUTs input into an array, in an order corresponding to the channels input. */
function sortLUTs(LUTs_input){
	LUTs_input = replace(LUTs_input, " ", ""); // LUTs_input is a string
	LUTs_input = split(LUTs_input,",,");
	LUTs_sorted = LUTs_input;
	return LUTs_sorted;
}


/****************************************************************************************************************************************************/
/* BASIC STRUCTURE FOR RECURSIVE DATA PROCESSING
 *
 * The overal logic is that each image/file is first opened and then the process is selected.
 * I wanted the logic to be: select process, then cycle through images, but this would require to pass function names as variables
 * and I don't know how to do that in Fiji, and if it is, in fact, possible.
 * Makes a list of contents of specified folder (folders and files) and goes through it one by one.
 * If it finds another directory, it enters it and makes a new list and does the same. In this way, it enters all subdirectories and looks for files.
 * If a list item is an image of type specified in the 'extension_list', it runs processFile() with selected process on that image file.
 */
function processFolder(dir, processing_function){
	list = getFileList(dir);
	for (i = 0; i < list.length; i++){
		if (endsWith(list[i], "/")){
			processFolder("" + dir + list[i], processing_function); // Recursively process subfolders
		} else {
			file = dir + list[i];
			title = File.getNameWithoutExtension(file);
			extension = substring(file, lastIndexOf(file, ".") + 1);
			if (endsWith(dir, "/" + dir_kymogram_source_data + "/") && indexOf(list[i], subset) >= 0 && endsWith(File.getParent(dir), image_type) && contains(extension_list, extension)){
				i = processFile(processing_function, i);
			}
		}
	}
}

/* Crossroad for the selection of processing based on user selection in initialDialogWindow() function.
 * Returns the value of i, which is used as a file list counter in the processFolder function.
 * This is required for the functionality of the displayKymograms() function (display previous/next/this image).
 */
function processFile(process, i){
	if (matches(process, process_choices[0])){			/* "Draw ROIs" */
		setBatchMode(false);
		drawROIs();
		setBatchMode(true);
	} else if (matches(process, process_choices[1])){	/* "Create kymograms" */
		createKymograms();
	} else if (matches(process, process_choices[2])){	/* "Display kymograms" */
		setBatchMode(false);
		i = displayKymograms(i);
		setBatchMode(true);
	} else if (matches(process, process_choices[3])){	/* "Filter kymograms" */
		filterKymograms();
	} else if (matches(process, process_choices[4])){	/* "Analyze kymograms" */
		startAnalysis();
	} else {											/* "EXIT" */
		closeAllWindows();
		exit();
	}
	return i;
}


/****************************************************************************************************************************************************/
/* MANUAL PREPARATION OF ROIS (REGIONS OF INTEREST)
 *
 * Manually draw ROIs and add them to the ROI Manager. The ellipse tool is preselected, but any type of object(area selection)/line is possible.
 * Any object is converted to a line that circumscribes it.
 */
function drawROIs(){
	clean_title = prepareImage();
	prepareROIs(clean_title);
	run("Maximize");
	setTool("ellipse");
	message = "Make ROIs by drawing them and pressing 't'\n"
		+ "(or press the 'Add [t]' a button in the ROI manager)\n"
		+ "after each to add them to the ROI Manager.\n"
		+ "The ellipse tool is preselected, but any type of ROI is possible";
	waitForUser(message);
	while (roiManager("count") == 0){
		waitForUser(message);
	}
	roiManager("Remove Channel Info");
	roiManager("Remove Slice Info");
	roiManager("Remove Frame Info");
	roiManager("Save", dir_ROIs + clean_title + RoiSet_suffix);
	close("*");
}


/****************************************************************************************************************************************************/
/* CALCULATION OF KYMOGRAMS FROM PROCESSED (DRIFT- AND/OR BLEACH CORRECTED) DATA
 *
 * Calculate a kymogram for each defined ROI and save it in a designated folder: "kymograms/<image_name>/raw/".
 * Function also lists all files that do not have any ROIs defined, which means that no kymograms can be made.
 */
function createKymograms(){
	clean_title = prepareImage();
	prepareKymogramDirs(clean_title);
	num_of_ROIs = prepareROIs(clean_title);
	if (num_of_ROIs == 0){
		logFilesWithout("ROIs");
	}
	last_ROI = num_of_ROIs;
	if (test == true)
		last_ROI = last_ROI_test;
	for (j = 0; j < last_ROI; j++){
		showProgress(-j/last_ROI);
		selectWindow(clean_title);
		roiManager("Select", j);
		if (selectionType < 5 || selectionType == 9)
			run("Area to Line");
		run("Reslice [/]...", "output=1.000 start=Top avoid");
		if (image_channels > 1)
			Stack.setDisplayMode("composite");
		setLUTs(true);
		kymogram_path = dir_kymograms_image_raw + "ROI_" + j + 1;
		saveAs("TIFF", kymogram_path);
		close();
	}
	close(clean_title);
}


/****************************************************************************************************************************************************/
/* DISPLAY OF CALCULATED KYMOGRAMS IN THEIR RAW (REGULAR) OR DIRECTION-FITLERED FORM, IF AVAILABLE
 *
 * Display selected kymograms for the selected (opened) image. By default, regular (raw) kymograms are displayed.
 * If the kymograms have already been filtered into main directions (filterKymograms function), these can be displayed as well.
 * There is an option to go to next/previous image, as well as select a specific image, or EXIT the step, if desired.
 * Kymograms for all channels are displayed at the same time, grouped by channels, in a tiled fashion.
 * Kymograms can be displayed in their original LUTs, as defined in the initial Dialog window, or in greyscale.
 * They can be stretched in y-direction (time dimension) for better visibility of details. Note that these are interpolated and are for display only.
 */
function displayKymograms(k){
	clean_title = prepareImage();
	prepareKymogramDirs(clean_title);
	if (findKymograms(dir_kymograms_image, 0, ".tif") == 0){
		waitForUser("No kymograms found for this image.");
		logFilesWithout("kymograms");
		close();
		return k;
	}
	num_of_ROIs = prepareROIs(clean_title);
	this_img = "> this image <";
	next_img = "-> next image";
	prev_img = "<- previous image";
	fourier_filters = newArray("FILTERED-forward", "FILTERED-backward", "FILTERED-static", "FILTERED-merged");
	traces_images = newArray("TRACES-forward", "TRACES-backward", "TRACES-static");
	display_options = newArray("regular");
	if (findKymograms(dir_kymograms_image, 0, "-merged.tif") > 0)
		display_options = Array.concat(display_options, fourier_filters);
	if (findKymograms(dir_kymograms_image, 0, "-traces.tif") > 0)
		display_options = Array.concat(display_options, traces_images);
	kymogram_path = dir_kymograms_image_raw;
	kymogram_list = listFiles(kymogram_path);
	kymogram_count = kymogram_list.length;
	kymogram_IDs_string = "" + 1 + "-" + kymogram_count;
	list_plus = Array.concat(this_img, next_img, prev_img, list, "EXIT");
	display_next = this_img;
	excluded_string = findExcluded(kymogram_path);
	display_type = "regular";
	time_stretch = 1;
	combined_display = "no";
	grayscale_boolean = "no";

	while (display_next == this_img){
		help_message = "<html>"
			+ "Selected kymograms are displayed alongside the original image that shows the defined ROIs. <br><br>"

			+ "<b>Image</b><br>"
			+ "Select image for which you desire to display kymograms. <br><br>"

			+ "<b>Kymograms</b><br>"
			+ "Select which kymograms you wish to display. "
			+ "For specification of multiple ROIs, comma-separated lists, ranges and their combinations are valid as input. <br><br>"

			+ "<b>Kymogram type</b><br>"
			+ "Select the type of kymograms to display. By default, the regular (raw) ones are displayed. "
			+ "If direction-filtered and prominent traces have been calculated, they can be displayed as well. "
			+ "In this case, the regular ones are displayed in the top of the screen, followed by the selected type. "
			+ "This makes it easier to correlate everything together. <br><br>"
			
			+ "<b>Combined display</b><br>"
			+ "Select if you want to display regular kymograms together with the selected filtered/traces version. <br><br>"

			+ "<b>Grayscale</b><br>"
			+ "Select if you want to display the kymograms in colours or greyscale. "
			+ "The colours of regular kymograms are specified by the user in the initial dialog window. "
			+ "The colours of direction-filtered images are hard-coded and are as follows: forward - magenta, backward - cyan, static - yellow. <br><br>"

			+ "<b>Stretch in time</b><br>"
			+ "Select how much the kymograms should be stretched in the y-dimension for display. "
			+ "Note that this only affects the display to facilitate the visual inspection of the kymogram and has no effect on the downstream analysis. <br><br>"

			+ "<b>Exclude/Restore kymograms</b><br>"
			+ "Specify the ROIs/kymograms that should be excluded from both display and analysis. "
			+ "For specification of multiple ROIs, comma-separated lists, ranges and their combinations are valid as input. "
			+ "Currently excluded ROIs/kymograms are listed above these options and can be restored using the second of the options. <br><br>"

			+ "</html>";
		Dialog.createNonBlocking("Select ROIs for display:");
			Dialog.addMessage("Current image (" + k+1 + "/" + list.length + "): " + list[k]);
			Dialog.addChoice("Image:", list_plus, this_img);
			Dialog.addString("Kymograms:", kymogram_IDs_string);
			Dialog.addChoice("Kymogram type:", display_options, display_type);
			Dialog.addChoice("Combined display:", boolean, combined_display);
			Dialog.addChoice("Greyscale:", boolean, grayscale_boolean);
			Dialog.addNumber("Stretch in time:", time_stretch);
			Dialog.addMessage("Currently excluded kymograms:" + excluded_string);
			Dialog.addString("Exclude kymograms:", "");
			Dialog.addString("Restore kymograms:", "");
			Dialog.setLocation(0, screenHeight*5.5/9);
			Dialog.addHelp(help_message);
			Dialog.show();
			display_next = Dialog.getChoice();
			kymogram_IDs_string = Dialog.getString();
			display_type = Dialog.getChoice();
			combined_display = Dialog.getChoice();
			grayscale_boolean = Dialog.getChoice();
			time_stretch = Dialog.getNumber();
			kymograms_to_exclude = sortIDs(Dialog.getString());
			kymograms_to_include = sortIDs(Dialog.getString());
		kymogram_IDs = sortIDs(kymogram_IDs_string);

		close("ROI*");

		kymogram_path = dir_kymograms_image_raw;
		suffix = ".tif";
		
		if (kymograms_to_exclude.length > 0)
			excludeKymograms(kymograms_to_exclude, "exclude");
		if (kymograms_to_include.length > 0)
			excludeKymograms(kymograms_to_include, "include");
		excluded_string = findExcluded(dir_kymograms_image_raw);
		excluded_array = sortIDs(excluded_string);
		offset = screenHeight/9;

		if (display_next != this_img)
			break;

		if (grayscale_boolean == "yes")
			grayscale = true;
		else
			grayscale = false;
			
		// display regular kymograms regardless of selected option
		// This way, these are displayed either alone or together with the direction-filtered one or respective isolated traces
		if (display_type == "regular" || combined_display == "yes"){
			for (c = 0; c < channels.length; c++){
				offset = showKymograms(kymogram_path, suffix, offset, channels[c], grayscale);
			}
		}
		// display direction-filtered kymograms or traces based on user input
		if (contains(fourier_filters, display_type) || contains(traces_images, display_type)){
			suffix = replace(replace(display_type, "FILTERED", ""), "TRACES", "") + suffix;
			if (contains(traces_images, display_type)){
				suffix = replace(suffix, ".tif", "-traces.tif");
				time_stretch = time_stretch/20;
			}
			// identify folders that contain direction-filtered images
			filtered_folders = newArray();
			kymofolders = getFileList(dir_kymograms_image);
			for (j = 0; j < kymofolders.length; j++){
				if (startsWith(kymofolders[j], "filtered"))
					filtered_folders[j] = kymofolders[j];
			}
			// cycling through available channels
			for (c = 0; c < filtered_folders.length; c++){
				kymogram_path = dir_kymograms_image + filtered_folders[c];
				offset = showKymograms(kymogram_path, suffix, offset, 1, grayscale);
			}
			if (contains(traces_images, display_type)){
				time_stretch = time_stretch*20;
			}
		}
	}
	close("*");
	k = nextImageIndex(display_next, k);
	return k-1;
}

/* Clear ROI manager, prepare directory for ROI Set storage, if it does not exist, open ROI Set corresponding to the current image, if it exists.
 * Remove information about channels before saving the current ROIs - the same ROIs are used for all available channels.
 * Count ROIs and return this number as function output.
 */
function prepareROIs(img_title){
	roiManager("reset");
	dir_ROIs = File.getParent(dir) + "/" + replace(File.getName(dir), dir_kymogram_source_data, "ROIs") + "/";
	if (!File.exists(dir_ROIs))
		File.makeDirectory(dir_ROIs);
	ROI_set_file = dir_ROIs + img_title + "-RoiSet.zip";
	if (File.exists(ROI_set_file))
		roiManager("Open", ROI_set_file);
	roiManager("Show All with labels");
	roiManager("Remove Channel Info");
	n = roiManager("count");
	return n;
}

/* Count the number of kymograms with the specified suffix.
 * This is used to check whether an image has defined kymograms (for purposes of display and analysis,
 * to see if filtered kymograms are available, etc.
 */
function findKymograms(path, count, suffix){
	file_list = getFileList(path);
	for (i = 0; i < file_list.length; i++){
		if (endsWith(file_list[i], "/"))
			count = findKymograms("" + path + file_list[i], count, suffix);
		else if (startsWith(file_list[i], "ROI_") && endsWith(file_list[i], suffix))
			count++;
	}
	return count;
}

/* Make a list of all files (i.e., exclude directories - these are included when using the native getFileList() function. */
function listFiles(path){
	list = getFileList(path);
	for (i = list.length-1 ; i >= 0 ; i--){
		if (endsWith(list[i], "/"))
			list = Array.deleteIndex(list, i);
	}
	return list;
}

/* Find ROIs marked as excluded, so they can be listed in the dialog window. These are ignored when kymograms are displayed and quantified. */
function findExcluded(dir){
	string = "";
	array = getFileList(dir);
	for (i = 0; i < array.length; i++){
		if (indexOf(array[i], "excluded") > 0){
			ROI_no = replace(replace(array[i], "-excluded.tif", ""), "ROI_", "");
			string = string + ROI_no + ", ";
		}
	}
	return string;
}

/* Sort user input of kymograms to be displayed (for example). Specific channels, ranges, or their combinations can be used as input,
 * including ranges going from highest to lowest number. If a range is defined, use the lower number as the beginning and the higher as end value.
 * Create an array containing these and all integer numbers between them. Duplicates are removed.
 */
function sortIDs(string){
	string = replace(string, " ", "");
	array = split(string,",,");
	array_temp = newArray(0);
	for (i = array.length-1; i >= 0; i--){
		if (indexOf(array[i], "-") >= 0){
			string_temp = split(array[i],"--");
			for (k = 0; k <= 1; k++){
				string_temp[k] = parseInt(string_temp[k]);
			}
			string_temp = Array.sort(string_temp);
			for (k = string_temp[0]; k <= string_temp[1]; k++){
				array_temp = Array.concat(array_temp, k);
			}
			array = Array.deleteIndex(array, i);
		}
	}
	// concatenate arrays and turn all items into integers (one of the things above creates strings)
	// substitute out of bounds values with nearest valid input (safety measure to avoid errors and macro crash)
	array = Array.concat(array, array_temp);
	for (i = 0; i < array.length; i++){
		array[i] = parseInt(array[i]);
		if (process == "Display kymograms" && array[i] > kymogram_list.length)
			array[i] = kymogram_list.length;
		if (array[i] < 1)
			array[i] = 1;
	}
	// sort array in ascending order and remove duplicates from the list of ROIs to be display to avoid displaying same ROI multiple times
	// used algorithm for removal of duplicates requires a sorted array
	array = Array.sort(array);
	if (array.length > 1){
		for (i = array.length-2; i >= 0; i--){
			if (array[i] == array[i+1])
				array = Array.deleteIndex(array, i);
		}
	}
	return array;
}

/* Append "-exluded" to the end of user-specified ROI files. These are ignored when kymograms are displayed and quantified. */
function excludeKymograms(list, operation){
	for (i = 0; i < list.length; i++){
		if (operation == "exclude"){
			old_name = kymogram_path + "ROI_" + list[i] + ".tif";
			new_name = replace(old_name, "ROI_" + list[i] + ".tif", "ROI_" + list[i] + "-excluded.tif");
		} else if (operation == "include"){
			old_name = kymogram_path + "ROI_" + list[i] + "-excluded.tif";
			new_name = replace(old_name, "-excluded", "");
		}
		File.rename(old_name, new_name);
		close("Log");
	}
}

/* Display the actual kymorams, with the defined attributes: time_stretch, LUT, etc.
 * Kymograms are displayed in a tiled manner, next to the original image.
 * If multiple channels are defined, images for respective channels are goruped and displayed next to each other.
 */
function showKymograms(kymogram_path, suffix, offset_y, ch, display_in_grayscale){
	offset_x = screenWidth/3;
	kymogram_height = 0;
	for (j = 0; j < kymogram_IDs.length; j++){
		kymogram = kymogram_path + "ROI_" + kymogram_IDs[j] + suffix;
		if (!contains(excluded_array, kymogram_IDs[j]) && File.exists(kymogram)){
			open(kymogram);
			getDimensions(w, h, kymogram_channels, s, f);
			if (ch <= kymogram_channels){
				kymo_title = getTitle();
				if (offset_x + w >= screenWidth){
					offset_x = screenWidth/3;
					offset_y += kymogram_height;
				}
				if (time_stretch != 1){
					run("Scale...", "x=1.0 y=" + time_stretch + " z=1.0 depth=2 interpolation=Bilinear average create");
					rename(kymo_title + "-stretched");
					close(kymo_title);
					rename(kymo_title);
				}
				if (display_in_grayscale == true){
					getDimensions(W, H, CH, S, F);
					for (c = 1; c <= CH; c++){
						Stack.setChannel(c);
						run("Grays");
					}
				} else if (suffix == ".tif"){
					run(LUTs[ch-1]);
				}
				if (suffix != "-merged.tif"){
					if (kymogram_channels > 1){
						Stack.setDisplayMode("color");
						Stack.setChannel(ch);
					}
				}
				setLocation(offset_x, offset_y);
				run("View 100%");
				getLocationAndSize(x, y, kymogram_width, kymogram_height);
				offset_x += kymogram_width;
			} else {
				getLocationAndSize(x, y, kymogram_width, kymogram_height);
				close();
				j = kymogram_IDs.length;
			}
		}
	}
	return offset_y + kymogram_height;
}

/* Based on user input, find the index of the specified image in the list (array) of possible choices. This is used to display the desired image. */
function nextImageIndex(next, index){
	if (next == prev_img){
		if (index == 0) // displayed image is the first in the current folder
			waitForUser("This is the first image of the series, there is no previous image.");
		else
			index--;
	} else if (next == next_img){
		index++;
		if (index >= list.length)
			return index-1;
	} else { // if a specific image is chosen from the list, its index needs to be found
		index = getArrayIndex(list, next);
	}
	return index;
}

/* Find the position in given array of the specified value. */
function getArrayIndex(array, value){
	for (i = 0; i < array.length; i++)
		if (array[i] == value)
			return i;
	return "not in array";
}


/****************************************************************************************************************************************************/
/* CALCULATION OF DIRECTION-FILTERED KYMOGRAMS FROM RAW KYMOGRAMS
 *
 * Filter kymograms based on dominant directions and save the resulting images in a designated folder: "kymograms/<image_name>/filtered-ch<c>/".
 * The relevant directions are: forward, backward and static (non-mobile). These are later used to calculate average speeds of traces.
 *
 * The approach and function in based with modifications, on:
 * Mangeol P, Prevo B, Peterman EJ.
 * KymographClear and KymographDirect: two tools for the automated quantitative analysis of molecular and cellular dynamics using kymographs.
 * Mol Biol Cell. 2016;27(12):1948-1957. doi:10.1091/mbc.E15-06-0404
 */
function filterKymograms(){
	for (c = 1; c <= 3; c++){
		current_channel = c;
		if (contains(channels, current_channel) && (current_channel <= image_channels)){
			clean_title = prepareImage();
			background = measureImageBackground(clean_title);
			selectWindow(clean_title);
			run("Z Project...", "projection=[Average Intensity]");
			Stack.setChannel(current_channel);
			prepareKymogramDirs(clean_title);
			if (findKymograms(dir_kymograms_image, 0, ".tif") == 0){
				logFilesWithout("kymograms");
			}
			dir_kymograms_image_filtered = dir_kymograms_image + "filtered-ch" + current_channel + "/";
			if (!File.exists(dir_kymograms_image_filtered))
				File.makeDirectory(dir_kymograms_image_filtered);
			num_of_ROIs = prepareROIs(clean_title);
			ROI_list = getFileList(dir_kymograms_image_raw);
			for (j = 0; j < num_of_ROIs; j++){
				showProgress(-j/num_of_ROIs);
				selectWindow("AVG_" + clean_title);
				run("Clear Results");
				roiManager("Select", j);
				run("Measure");
				ROI_mean = getResult("Mean", 0);
				kymogram = dir_kymograms_image_raw + ROI_list[j];
				if (!endsWith(kymogram, "-excluded.tif")){
					open(kymogram);
					kymogram_title = File.nameWithoutExtension();
					rename(kymogram_title);
					Stack.setChannel(current_channel);
					getDimensions(kymogram_width, kymogram_height, CH, S, F);
					findMainDirections(kymogram_title);
					max_filtered_intensity = getMaxFilteredIntensity(kymogram_title);
					saveFilteredKymograms(kymogram_title);
					extractKymogramTraces(kymogram_title);
					extractMobilityMasks(kymogram_title);
					close(kymogram_title);
				}
			}
			close("*" + clean_title);
		}
	}
}

/* The original kymogram is transformed using fourier transformation into frequency domain.
 * This allows filtering of the image based on dominant directions: forward, backward, vertical and horizontal. The last one is not relevant when dealing with kymograms.
 * The filtering is achieved by removing parts of the fourier image, such as diagonal quadrants, or other sections, and then transforming the image back.
 * For more information on this filtering, see Mangeol et al., 2016; doi: doi/10.1091/mbc.E15-06-0404. The following functions are based on their KymographClear macro.
 */
function findMainDirections(kymogram_image_name){
	crop_factor = 3;
	setForegroundColor(0, 0, 0);
	setBackgroundColor(0, 0, 0);
	run("Gaussian Blur...", "sigma=2");
	extendBorders();
	run("16-bit");
	for (k = 0; k < filters.length; k++){
		selectWindow("extended");
		run("Duplicate...", "title=[" + filters[k] + "]");
		selectWindow(filters[k]);
		if (k != 2){
			if (k == 1)
				run("Flip Horizontally");
			run("FFT");
			getDimensions(width, height, img_channels, slices, frames);
			fillRect(0, 0, width/2 + crop_factor, height/2 + crop_factor);
			fillRect(width/2 - crop_factor, height/2 - crop_factor, width/2 + crop_factor, height/2 + crop_factor);
		} else {
			run("FFT");
			getDimensions(width, height, img_channels, slices, frames);
			makePolygon(0 - crop_factor, 0, width/2, height/2 + crop_factor, width + crop_factor, 0);
			run("Clear", "slice");
			makePolygon(0 - crop_factor, height, width/2, height/2 - crop_factor, width + crop_factor, height);
			run("Clear", "slice");
		}
		run("Inverse FFT");
		if (k == 1)
			run("Flip Horizontally");
		makeRectangle(kymogram_width, kymogram_height, kymogram_width, kymogram_height);
		run("Crop");
		rename("FILTERED-" + filters[k]);
		close(filters[k]);
	}
	close("FFT *");
	close("extended");
}

/* Measure the maximum intensity from within a given set of direction-filtered kymograms. */
function getMaxFilteredIntensity(image){
	max_0 = 0;
	for (k = 0; k < filters.length; k++){
		selectWindow("FILTERED-" + filters[k]);
		getStatistics(area, mean, min, max, std, histogram);
		if (max > max_0){
			max_0 = max;
		}
	}
	return max_0;
}

/* Save the direction-filtered kymograms in the designated folder:"kymograms/<image_name>/filtered-ch<c>/". */
function saveFilteredKymograms(kymogram_image_name){
	for (k = 0; k < filters.length; k++){
		selectWindow("FILTERED-" + filters[k]);
		setMinAndMax(0, max_filtered_intensity*0.95);
		run(LUTs_filtered[k]);
		saveAs("TIFF", dir_kymograms_image_filtered + kymogram_image_name + "-" + filters[k]);
		rename("FILTERED-" + filters[k]);
	}
	run("Merge Channels...", "c1=[FILTERED-forward] c2=[FILTERED-backward] c3=[FILTERED-static] create keep");
	saveAs("TIFF", dir_kymograms_image_filtered + kymogram_image_name + "-merged");
	close(kymogram_image_name + "-merged.tif");
}

/* Process the direction-filtered kymograms to extract individual traces in the forms of skeletons for the purpose of speed and lifetime quantification. */
function extractKymogramTraces(kymogram_image_name){
	selectWindow(kymogram_image_name);
	bit_depth = bitDepth();
	threshold_min = max_filtered_intensity/3;
	if (ROI_mean < background)
		threshold_min = pow(2, bit_depth) - 1;
	threshold_max = pow(2, bit_depth) - 1;
	time_stretch = 20;
	setOption("BlackBackground", true);
	for (k = 0; k < filters.length; k++){
		selectWindow("FILTERED-" + filters[k]);
		Image.removeScale;
		run("Scale...", "x=1.0 y=" + time_stretch + ".0 z=1.0 depth=2 interpolation=None average create");
		setThreshold(threshold_min, threshold_max, "raw");
		run("Create Mask");
		extendBorders();
		run("Skeletonize");
		makeRectangle(kymogram_width, kymogram_height*time_stretch, kymogram_width, kymogram_height*time_stretch);
		run("Crop");
		saveAs("TIFF", dir_kymograms_image_filtered + kymogram_image_name + "-" + filters[k] + "-traces");
		close();
		close("extended");
		close("mask");
		close("*" + filters[k] + "*");
	}
}


/* To avoid loss of information during fourier transformations and filtering, the original kymogram image is extended in x and y dimensions, in a kaleidoscopic manner. */
function extendBorders(){
	run("Duplicate...", "title=DUP"); // duplicates only current channel
	run("Duplicate...", "title=extended");
	getDimensions(width, height, img_channels, slices, frames);
	run("Canvas Size...", "width=" + 3*width + " height=" + 3*height + " position=Center");
	selectWindow("DUP");
	run("Rotate... ", "angle=180 grid=1 interpolation=None");
	run("Copy");
	selectWindow("extended");
	for (i = 0; i <= 2; i+=2){
		for (j = 0; j <= 2; j+=2){
			makeRectangle(i*width, j*height, width, height);
			run("Paste");
		}
	}
	selectWindow("DUP");
	run("Flip Vertically");
	run("Copy");
	selectWindow("extended");
	for (i = 0; i <= 2; i+=2){
		makeRectangle(i*width, height, width, height);
		run("Paste");
	}
	selectWindow("DUP");
	run("Rotate... ", "angle=180 grid=1 interpolation=None");
	run("Copy");
	selectWindow("extended");
	for (i = 0; i <= 2; i+=2){
		makeRectangle(width, i*height, width, height);
		run("Paste");
	}
	run("Select None");
	close("DUP");
}

function extractMobilityMasks(kymogram_ID){
	selectWindow(kymogram_ID);
	bit_depth = bitDepth();
	threshold_min = max_filtered_intensity/3;
	if (ROI_mean < background)
		threshold_min = pow(2, bit_depth) - 1;
	threshold_max = pow(2, bit_depth) - 1;
	for (k = 0; k < 2; k++){
		open(dir_kymograms_image_filtered + kymogram_ID + "-" + filters[k] + ".tif");
		title = getTitle();
		setThreshold(threshold_min, threshold_max, "raw");
		run("Create Mask");
		close(title);
	}

	run("Images to Stack", "  title=mask use");

	run("Z Project...", "projection=[Max Intensity]");
	run("16-bit");
	saveAs("TIFF", dir_kymograms_image_filtered + kymogram_ID + "-mask");
	close();
	close("Stack");
}

/****************************************************************************************************************************************************/
/* KYMOGRAM ANALYSIS
 *
 * Multiple parameters are extracted from the raw or direction-filtered kymograms:
 * -> mean speed in different directions: forward, backward, and non-mobile
 * -> coupling/colocalization, time that signals spend together, how fast they are moving when do do, what fraction of time they are coupled
 * -> coefficient of variation
 */

/* Get user input for the analysis. */
function startAnalysis(){
	if (just_started == true){
		help_message = "<html>"
			+ "<b>Naming scheme</b><br>"
			+ "Specify how your files are named (without extension). Results are reported in a comma-separated table, with the parameters specified here used as column headers. "
			+ "The default \"<i>strain,medium,time,condition,frame</i>\" creates 5 columns, with titles \"strains\", \"medium\" etc. "
			+ "Using a consistent naming scheme across your data enables automated downstream data processing. <br><br>"

			+ "<b>Experiment code scheme</b><br>"
			+ "Specify how your experiments are coded. The macro assumes a folder structure of <i>\".../experimental_code/biological_replicate_date/image_type/data/\"</i>. "
			+ "See protocol [1] for details. <br><br>"

			+ "<b>Image type</b><br>"
			+ "Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells. <br><br>"

			+ "<b>Subset</b><br>"
			+ "If used, only images with filenames containing specified <i>string</i> (i.e., group of characters and/or numbers) will be processed. "
			+ "This option can be used to selectively process images of a specific strain, condition, etc. "
			+ "Leave empty to process all images in specified directory (and its subdirectories). <br><br>"

			+ "<b>First channel (obligatory)</b><br>"
			+ "Image kymograms corresponding to the specified channel will be analyzed. <br><br>"

			+ "<b>Second channel (optional)</b><br>"
			+ "If specified (available), kymograms corresponding to this channel will also be analyzed. "
			+ "In addition, the the overlap (colocalization) of the kymograms corresponding to the two specified channels will be analyzed. <br><br>"

			+ "<b>Continue previous analysis</b><br>"
			+ "If a previous analysis run have not finished successfully for some reason, it can be resumed using this option. "
			+ "If selected, the results from already analyzed images will be loaded and the results from subsequently analyzed images will be added to theses, "
			+ "thus resulting in a single Results table. <br><br>"

			+ "<b>References:</b><br>"
			+ "[1] " + publication + " <br>"
//			+ "[2] " + GitHub_microscopy_analysis + " <br>";
			+ "</html>";
		if (channels.length < 2)
			channels = Array.concat(channels, NaN);
		Dialog.create("Specify analysis parameters:");
			Dialog.addString("Naming scheme:", default_naming_scheme, 33);
			Dialog.addString("Experiment code scheme:", "XY-M-000", 33);
			Dialog.addChoice("Image type:", image_types, image_type);
			Dialog.addString("Subset (optional):", "");
			Dialog.addNumber("First channel:", channels[0]);
			Dialog.addNumber("Second channel:", channels[1]);
			Dialog.addCheckbox("Continue previous analysis", continue_analysis);
			Dialog.addHelp(help_message);
			Dialog.show();
			naming_scheme = Dialog.getString();
			experiment_scheme = Dialog.getString();
			image_type = Dialog.getChoice();
			subset = Dialog.getString();
			channel_A = Dialog.getNumber();
			channel_B = Dialog.getNumber();
			continue_analysis = Dialog.getCheckbox();

		if (!isNaN(channel_B)){
			channels_to_analyze = newArray(channel_A, channel_B);
			channel_sum = channel_A + channel_B;
		} else {
			channels_to_analyze = newArray();
			channels_to_analyze[0] = channel_A;
			channel_sum = channel_A;
		}
		just_started = false; // this (global) variable is used so that this Dialog window is displayed only when the analysis is started and not when each new image is opened
	}

	// based on the current situation, prepare the environment for the actual analysis
	for (c = 0; c < channels_to_analyze.length; c++){
		current_channel = channels_to_analyze[c];
		if (contains(channels, current_channel) && current_channel <= image_channels){
			temporary_results_file = "results-temporary_channel_" + current_channel + ".csv";
			processed_images_file = "processed_images_channel_" + current_channel + ".csv";
			processed_images = "";
			if (!isOpen(temporary_results_file))
				initializeAnalysis();
			if (continue_analysis == true && File.exists(dir_master + temporary_results_file) && File.exists(dir_master + processed_images_file))
				processed_images = File.openAsString(dir_master + processed_images_file);
			if (indexOf(list[i], subset) >= 0 && indexOf(processed_images, file) < 0)
				analyzeKymograms(temporary_results_file, processed_images_file);
		}
	}
}

/* Create new text windows to write temporary results and names of processed files. */
function initializeAnalysis(){
	column_width = screenWidth/channels_to_analyze.length;
	run("Text Window...", "name=[" + temporary_results_file + "] width=96 height=32");
	setLocation((current_channel - 1)*column_width, 0);
	run("Text Window...", "name=[" + processed_images_file + "] width=96 height=32");
	setLocation((current_channel - 1)*column_width, screenHeight/2);
	if (continue_analysis == true && File.exists(dir_master + temporary_results_file)){ // if File.exists() - when the analysis is continued and multiple channels are selected, some may not have temporary files
		print("[" + temporary_results_file + "]", File.openAsString(dir_master + temporary_results_file));
		processed_images_list = File.openAsString(dir_master + processed_images_file);
		print("[" + processed_images_file + "]", processed_images_list);
	} else {
		printResultsHeader();
	}
}

/* Print the header of the Results file, including basic information on the macro run and column titles */
function printResultsHeader(){
	getDateAndTime(start_year, start_month, start_dayOfWeek, start_dayOfMonth, start_hour, start_minute, start_second, start_msec);
	// print the header of the Results output file
	// the first couple of lines give a general overview of the analysis run
	print("[" + temporary_results_file + "]","# Basic macro run statistics:" + "\n");
	print("[" + temporary_results_file + "]","# Macro name: " + macro_name + "\n");
	print("[" + temporary_results_file + "]","# Macro version: " + version + "\n");
	print("[" + temporary_results_file + "]","# Date and time: " + start_year + "-" + String.pad(start_month + 1,2) + "-" + String.pad(start_dayOfMonth,2) + " " + String.pad(start_hour,2) + ":" + String.pad(start_minute,2) + ":" + String.pad(start_second,2)+ "\n");
	print("[" + temporary_results_file + "]","# Image type: " + image_type + "\n");
	print("[" + temporary_results_file + "]","# Channel: " + current_channel + "\n");
	print("[" + temporary_results_file + "]","#" + "\n");
	print("[" + temporary_results_file + "]","# Abbreviations:" + "\n");
	print("[" + temporary_results_file + "]","# bwd - backward" + "\n");
	print("[" + temporary_results_file + "]","# fwd - forward" + "\n");
	print("[" + temporary_results_file + "]","# stat - static" + "\n");
	print("[" + temporary_results_file + "]","# T - lifetime" + "\n");
	print("[" + temporary_results_file + "]","# v - speed" + "\n");
	print("[" + temporary_results_file + "]","#" + "\n"); // empty line that is ignored in bash and R
}

/* Run the actual analysis. */
function analyzeKymograms(res_file, proc_file){
	clean_title = prepareImage();
	prepareKymogramDirs(clean_title);
	background = measureImageBackground(clean_title);
	kymogram_list = getFileList(dir_kymograms_image_raw);
	// write out the name of an image if there are no kymograms defined for it and escape the function
	if (findKymograms(dir_kymograms_image, 0, ".tif") == 0){
		logFilesWithout("kymograms");
		return;
	}

	if (channels_to_analyze.length == 2 && image_channels > 1)
		analyze_overlap = true;
	if (column_names_printed[current_channel-1] == 0){
		printColumnNames();
		column_names_printed[current_channel-1] = 1;
	}
	// calculate multiple parameters for each individual kymogram
	for (j = 0; j < kymogram_list.length; j++){
		showProgress(-j/kymogram_list.length);
		kymogram = dir_kymograms_image_raw + kymogram_list[j];
		if (!endsWith(kymogram, "-excluded.tif")){
			open(kymogram);
			kymogram_title = File.nameWithoutExtension();
			rename(kymogram_title);
			Stack.setChannel(current_channel);
			getDimensions(kymogram_width, kymogram_height, CH, S, F);
			average_speeds_and_lifetimes = quantifyTraces(kymogram_title, "-traces.tif", kymogram_width, kymogram_height); // number of traces, mean speeds, mean lifetimes (grouped by direction)
			mean_speed_and_lifetime = calculateWeightedMeans(average_speeds_and_lifetimes);
			mobile_fraction = calculateMobileFraction(kymogram_title);
			if (analyze_overlap == true){
				average_speeds_and_lifetimes_coupled = analyzeCoupling(kymogram_title, kymogram_width, kymogram_height);
				mean_speed_and_lifetime_coupled = calculateWeightedMeans(average_speeds_and_lifetimes_coupled);
				coupled_lifetimes_fractions = calculateCouplingRatios(kymogram_title);
			}
			printResults();
		}
	}
	saveTemp(res_file, proc_file);
}

/* Open image file, place it in the top left corner of the image
 * and remove all suffixes that may be there (AVG, SUM, etc.).
 * This should result in the core file name, as it was originally saved after imaging.
 */
function prepareImage(){
	open(file);
	img_title = File.nameWithoutExtension;
	img_title_clean = cleanTitle(img_title);
	rename(img_title_clean);
	getPixelSize(unit, pixelWidth, pixelHeight);
	getDimensions(image_width, image_height, image_channels, image_slices, image_frames);
	FrameInterval();
	setLocation(0, 0, screenWidth/3, screenWidth/3);
	setLUTs(true);
	return img_title_clean;
}

/* Return the "original" core name, without any and all suffixes that might have been added during corrections and projections.
 * This makes handling of ROIs easier.
 */
function cleanTitle(string){
	suffixes = newArray("-AVG", "-SUM", "-MAX", "-MIN", "-processed", "-corr", "-crop", "-cropped");
	for (i = 0; i < suffixes.length; i++){
		string = replace(string, suffixes[i], "");
	}
	return string;
}

function FrameInterval(){
	frame_interval = Stack.getFrameInterval();
	if (frame_interval == 0){
		if (frame_interval_global != 0){
			interval = frame_interval_global;
		} else {
			Dialog.create("Set frame interval");
			Dialog.addMessage("Frame interval for:");
			Dialog.addMessage(img_title);
			Dialog.addMessage("not detected, input manually:");
			Dialog.addNumber("Frame interval (in seconds)", "");
			Dialog.addChoice("Apply to:", newArray("for current image", "for all images"));
			Dialog.show();
			interval = Dialog.getNumber();
			frame_interval_extent = Dialog.getChoice();
			if (frame_interval_extent == "for all images")
				frame_interval_global = interval;
		}
		Stack.setFrameInterval(interval);
		saveAs("TIFF", file);
	}
}

/* Set LUTs for individual channels based on user input inthe initial Dialog window. */
function setLUTs(enhance){
	for (i = 0; i < channels.length; i++){
		Stack.setChannel(channels[i]);
		run(LUTs[i]);
		if (enhance == true)
			run("Enhance Contrast", "saturated=0.01");
	}
}

/* Prepare the folders that contain kymograms - get their names and create them if they do not yet exist. */
function prepareKymogramDirs(clean_title){
	dir_kymograms_main = File.getParent(dir) + "/" + replace(File.getName(dir), dir_kymogram_source_data, "kymograms") + "/";
	dir_kymograms_image = dir_kymograms_main + clean_title  + "/";
	dir_kymograms_image_raw = dir_kymograms_image + "raw/";
	dir_kymograms_image_filtered = dir_kymograms_image + "filtered-ch" + current_channel + "/";
	dirList = newArray(dir_kymograms_main, dir_kymograms_image, dir_kymograms_image_raw);
	for (j = 0; j < dirList.length; j++){
		if (!File.exists(dirList[j]))
			File.makeDirectory(dirList[j]);
	}
}

/* To get an estimate of the image background, the background is subtracted in the original image using brute force (rolling ball approach).
 * The result is then subtracted from the original image, creating an image of the background.
 * The mean intensity of this image is then used as background intensity estimate.
 */
function measureImageBackground(image_title){
	selectWindow(image_title);
	run("Duplicate...", "title=DUP duplicate channels=" + current_channel);
	run("Z Project...", "projection=[Average Intensity]");
	run("Select None");
	getStatistics(area, mean, min, max, std, histogram);
	// If offset is set correctly during image acquisition, zero pixel intensity usually originates when multichannel images are aligned.
	// In this case, they need to be cropped before the background estimation.
	if (min == 0)
		run("Auto Crop (guess background color)");
	rename("DUP-CROP");
	run("Duplicate...", "duplicate");
	rename("DUP-CROP-background");
	// Brute-force background subtraction (by using the "rolling ball" approach), the width of the whole image is used as the diameter of the ball.
	run("Subtract Background...", "rolling=" + image_width + " stack");
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-background");
	getStatistics(area, mean, min, max, std, histogram);
	selectWindow("DUP-CROP");
	setThreshold(0, mean);
	run("Create Selection");
	// the mean intensity is measured as the background estimate for the raw image and returned by the function
	getStatistics(area, image_background_mean, min, max, image_background_std, histogram);
	close("DUP*");
	close("Result*");
	return image_background_mean;
}

/* Write out (into Log) file names of images/files that do not have the specified objects assigned to them:
 *  These could be ROIs or kymograms
 */
function logFilesWithout(string){
	affected_files_list = "images_without_" + string + ".csv";
	if (!isOpen(affected_files_list)){
		run("Text Window...", "name=[" + affected_files_list + "] width=200 height=32");
		setLocation(0, 0);
	}
	if (!contains(images_without_kymograms_array, file)){
		images_without_kymograms_array = Array.concat(images_without_kymograms_array, file);
		print("[" + affected_files_list + "]", file + "\n");
	}
}

/* Check if the given array contains the specified value. */
function contains(array, value){
	for (i = 0; i < array.length; i++)
		if (array[i] == value)
			return true;
	return false;
}

function printColumnNames(){
	column_names = "exp_code,BR_date,"
		+ naming_scheme + ",background_mean,frame_interval[s],cell_no"
		+ ",traces_fwd,traces_bwd,traces_stat"
		+ ",v_fwd[nm/s],v_bwd[nm/s],v_stat[nm/s]"
		+ ",T_fwd[s],T_bwd[s],T_stat[s]"
		+ ",mean_v[nm/s],mean_T[s]"
		+ ",mobile_fraction_percent";
	if (analyze_overlap == true)
		column_names += ",coupled_traces_fwd,coupled_traces_bwd,coupled_traces_stat"
			+ ",coupled_v_fwd[nm/s],coupled_v_bwd[nm/s],coupled_v_stat[nm/s]"
			+ ",coupled_T_fwd[s],coupled_T_bwd[s],coupled_T_stat[s]"
			+ ",coupled_fwd_fraction_percent,coupled_bwd_fraction_percent,coupled_stat_fraction_percent"
			+ ",coupled_mean_v[nm/s],coupled_mean_T[s]";
	print("[" + temporary_results_file + "]", column_names + "\n");
}

function calculateMobileFraction(kymogram_ID){
	run("Clear Results");
	open(dir_kymograms_image_filtered + kymogram_ID + "-mask.tif");
	bit_depth = bitDepth();
	threshold_max = pow(2, bit_depth) - 1;
	setThreshold(threshold_max/2, threshold_max, "raw");
	run("Convert to Mask");
	run("Create Selection");
	open(dir_kymograms_image_raw + kymogram_ID + ".tif");
	run("Measure");
	total_intensity = getResult("IntDen", 0) - background;
	Stack.setChannel(current_channel);
	run("Restore Selection");
	run("Measure");
	mobile_intensity = getResult("IntDen", 1) - background;
	close("Results");
	fraction = 100*mobile_intensity/total_intensity;
	// If there is absolutely no mobile signal, the "Create selection" command will select the whole image.
	// The fraction calculation returns 1, which is obviously wrong.
	// On the other hand, all signal being mobile is not possible; therefore, 0 is returned in this case.
	// Negative values can arise when a tiny area is selected for the mobile fraction due to background subtraction.
	// condition2 -> if there are no traces in forward and backward direction, there is no mobile fraction
	condition1 = (fraction == 1 || fraction < 0);
	condition2 = (average_speeds_and_lifetimes[0] + average_speeds_and_lifetimes[1] == 0);
	if (condition1 || condition2)
		return 0;
	else
		return fraction;
}

/* Analyze coupled movement/retention of two signals - lifetime and speed, and fraction of time the signals spend together */
function analyzeCoupling(image_title, width, height){
	overlap_image_suffix = findTracesOverlap(image_title);
	output_array = quantifyTraces(image_title, overlap_image_suffix, width, height);
	return output_array;
}

/* Calculate traces corresponding to colocalization of signal in the specified 2 channels. */
function findTracesOverlap(image_title){
	dir_filtered_names = newArray("ch" + current_channel, "ch" + channel_sum - current_channel);
	overlap_image_suffix = "-traces-overlapping_ch" + channel_sum - current_channel + ".tif";
	for (k = 0; k < filters.length; k++){
		for (i = 0; i < dir_filtered_names.length; i++){
			traces_file = dir_kymograms_image + "filtered-" + dir_filtered_names[i] + "/" + image_title + "-" + filters[k] + "-traces.tif";
			open(traces_file);
			run("Dilate");
			run("Dilate");
			rename(dir_filtered_names[i]);
		}
		imageCalculator("Multiply create", dir_filtered_names[0], dir_filtered_names[1]);
		run("Dilate");
		run("Skeletonize");
		saveAs("TIFF", dir_kymograms_image_filtered + image_title + "-" + filters[k] + overlap_image_suffix);
		rename("overlap");
		close("*");
	}
	return overlap_image_suffix;
}

/* Calculate the average speeds in the forward and backward direction from within individual kymograms.
 * The speed of static objects is included as a form of control - this should be close to zero.
 */
function quantifyTraces(image_title, suffix, width, height){
	output_array = newArray(9);
	for (k = 0; k < filters.length; k++){
		time_stretch = 20;
		traces_file = dir_kymograms_image_filtered + image_title + "-" + filters[k] + suffix;
		open(traces_file);
		run("Analyze Skeleton (2D/3D)", "prune=none show");
		close("Results");
		Table.rename("Branch information", "Results");
		averages = calculateAverages();
		output_array[k] = averages[0];
		output_array[k + 3] = averages[1];
		output_array[k + 6] = averages[2];
		close("Results");
		close("*");
	}
	return output_array;
}

/* Measure average speed and lifetime of traces that either start and finish within the kymogram or span the whole kymogram. */
function calculateAverages(){
	minimum_trace_length = 4*time_stretch;
	speeds_array = newArray();
	lifetimes_array = newArray();
	stretched_height = height*time_stretch-1; // the skeleton always ends at least 1 pixel before end
	trace_count = nResults;
	for (i = 0; i < nResults; i++){
		length = getResult("Branch length", i);
		trace_start = getResult("V1 y", i);
		trace_finish = getResult("V2 y", i);
		lifetime_raw = trace_finish - trace_start;
		condition1 = (length >= minimum_trace_length); // trace needs to be longer than 3 pixels in raw image
		condition2 = (trace_start != 0) && (trace_start != stretched_height); // trace must start and finish within the kymogram
		condition3 = (trace_finish != 0) && (trace_finish != stretched_height);
		alt_condition = (abs(lifetime_raw) == stretched_height); // or trace must span the whole kymogram
		if ((condition1 && condition2 && condition3) || alt_condition){
			lateral_displacement = (getResult("V2 x", i) - getResult("V1 x", i))*pixelWidth*1000; // lateral displacement in nm
			lifetime = (lifetime_raw/time_stretch)*frame_interval; // lifetime in seconds
			lifetimes_array = Array.concat(lifetimes_array, abs(lifetime));
			speed = lateral_displacement/lifetime;
			if (-"Infinity" < speed && speed < "Infinity"){
				speeds_array = Array.concat(speeds_array, speed);
			}
		} else {
			trace_count -= 1; // only traces that are quantified are counted
		}
	}
	Array.getStatistics(lifetimes_array, min, max, lifetime_mean, stdDev);
	Array.getStatistics(speeds_array, min, max, speed_mean, stdDev);
	return newArray(trace_count, speed_mean, lifetime_mean);
}

/* Calculate weighted averages (means) of speeds and lifetimes; for this purpose, NaN values are replaced with 0.
 * This way, the respective traces do not contribute, and the value can actually be sensibly calculated.
 */
function calculateWeightedMeans(input_array){
	output_array = newArray(2);
	corrected_array = replaceInArray(input_array, NaN, 0);
	traces_count = corrected_array[0] + corrected_array[1] + corrected_array[2];
	output_array[0] = (abs(corrected_array[0]*corrected_array[3]) + abs(corrected_array[1]*corrected_array[4]) + abs(corrected_array[2]*corrected_array[5]))/traces_count;
	output_array[1] = (corrected_array[0]*corrected_array[6] + corrected_array[1]*corrected_array[7] + corrected_array[2]*corrected_array[8])/traces_count;
	return output_array;
}

/* Replace specified values in an array. */
function replaceInArray(input_array, old_value, new_value){
	output_array = newArray(input_array.length);
	for (i = 0; i < input_array.length; i++){
		if (isNaN(input_array[i]) || input_array[i] == old_value)
			output_array[i] = new_value;
		else
			output_array[i] = input_array[i];
	}
	return output_array;
}

/* Calculate the fraction of overlapping and total traces. */
function calculateCouplingRatios(image_title){
	output_array = newArray(3);
	temp_array = newArray(2);
	suffixes = newArray("-traces-overlapping_ch" + channel_sum - current_channel + ".tif", "-traces.tif");
	for (k = 0; k <= 2; k++){
		prefix = dir_kymograms_image_filtered + image_title + "-" + filters[k];
		run("Clear Results");
		for (l = 0; l <= 1; l++){
			open(prefix + suffixes[l]);
			run("Measure");
			temp_array[l] = getResult("IntDen", l);
			close();
		}
		output_array[k] = 100*temp_array[0]/temp_array[1];
		if (output_array[k] > 100)
			output_array[k] = 100;
	}
	return output_array;
}

/* Print results into the respective temporary_results window and write out what file was processed. */
function printResults(){
	parents = findParentDirs(); // [0] - experiment code, [1] - biological replicate date
	kymogram_results = parents[0] + "," + parents[1] // [0] - experiment code, [1] - biological replicate date
		+ "," + replace(title," ","_") + "," + background + "," + frame_interval + "," + (j+1) // image title, background intensity and current ROI number
		+ "," + String.join(average_speeds_and_lifetimes) // no. of traces, average speeds, average lifetimes (for forward, backward, static movement, respectively)
		+ "," + String.join(mean_speed_and_lifetime) // + "," + mean_speed + "," + mean_lifetime
		+ "," + mobile_fraction;
	if (analyze_overlap == true)
		kymogram_results += "," + String.join(average_speeds_and_lifetimes_coupled)
			+ "," + String.join(coupled_lifetimes_fractions)
			+ "," + String.join(mean_speed_and_lifetime_coupled);
	print("["+ res_file + "]", kymogram_results + "\n");
}

/* Find the names of the parent directory and of its parent. These contain the biological replicate date and experimental code, respectively. */
function findParentDirs(){
	dir_parent = File.getParent(File.getParent(dir)); // bio replicate date (two levels up from the "data" folder)
	dir_grandparent = File.getParent(dir_parent); // one level above the bio replicate folder; name starts with the experiment code (accession number)
	// replace spaces with underscores in both to prevent possible issues in automatic R processing of the Results table
	BR_date = replace(File.getName(dir_parent)," ","_");
	exp_code = replace(File.getName(dir_grandparent)," ","_");
	// date is expected in YYMMDD (or another 6-digit) format; if it is shorter, the whole name is used; analogous with the "experimental code"
	if (lengthOf(BR_date) > 6)
		BR_date = substring(BR_date, 0, 6);
	if (lengthOf(exp_code) > lengthOf(experiment_scheme))
		exp_code = substring(exp_code, 0, lengthOf(experiment_scheme));
	return newArray(exp_code, BR_date);
}

/* Save temporary results file and the list of processed files. This enables resuming of an interrupted analysis. */
function saveTemp(temporary_results_file, temp_proc_file){
	selectWindow(temporary_results_file);
	saveAs("Text", dir_master + temporary_results_file);
	print("[" + temp_proc_file + "]", file + "\n");
	selectWindow(temp_proc_file);
	saveAs("Text", dir_master + temp_proc_file);
}

/****************************************************************************************************************************************************/
/* CLEAN UP THE ENVIRONMENT
 *
 * Save Log windows with information on files missing ROIs and kymograms.
 * Save the Results at the end of analysis.
 * Close all windows (including text windows).
 */
function cleanUp(){
	if (matches(process, process_choices[1]) && isOpen(images_without_ROIs_list)){ /* "Create kymograms" */
		selectWindow(images_without_ROIs_list);
		saveAs("Text", dir_master + images_without_ROIs_list);
		waitForUser("One or more images do not have defined ROIs, see the Log. Define ROIs for these images and run the macro again.");
	}
	for (i = 2; i <= 4; i++){
		if (matches(process, process_choices[i]) && isOpen(images_without_kymograms_list)){ /* "Draw ROIs/Display kymograms/Filter kymograms/Analyze kymograms" */
			selectWindow(images_without_kymograms_list);
			saveAs("Text", dir_master + images_without_kymograms_list);
			waitForUser("One or more images do not have calculated kymograms, see the Log. Create kymograms for these images and run the macro again.");
		}
	}
	if (matches(process, process_choices[4])) /* "Analyze kymograms" */
		wrapUp();
	images_without_kymograms_array = newArray();
}

/* Save the analysis Results output in csv format and clean the Fiji (ImageJ) environment. */
function wrapUp(){
	for (c = 0; c < channels_to_analyze.length; c++){
		current_channel = channels_to_analyze[c];
		temporary_results_file = "results-temporary_channel_" + current_channel + ".csv";
		processed_images_file = "processed_images_channel_" + current_channel + ".csv";
		if (isOpen(temporary_results_file)){
			getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
			res = "Results of kymogram analysis, " + image_type + "," + " channel " + current_channel + " (" + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + "," + String.pad(hour,2) + "-" + String.pad(minute,2) + "-" + String.pad(second,2) + ").csv";
			selectWindow(temporary_results_file);
			saveAs("Text", dir_master + res);
			print("[" + res + "]", "\\Close");
		}
		File.delete(dir_master + temporary_results_file);
		File.delete(dir_master + processed_images_file);
	}
	closeAllWindows();
	waitForUser("Analysis finished!");
	just_started = true;
}

/* Close all open image windows and specific text windows that might be open. */
function closeAllWindows(){
	close("*");
	windows_list = newArray("ROI Manager", "Log", "Results", "Debug", "images_without_kymograms.csv", "images_without_ROIs.csv");
	for (i = 0; i < windows_list.length; i++){
		if (isOpen(windows_list[i]))
			close(windows_list[i]);
	}
	text_window_prefixes = newArray("results-temporary_channel_", "processed_images_channel_");
	for (i = 0; i < text_window_prefixes.length; i++){
		for (c = 0; c < 3; c++){
			text_window = text_window_prefixes[i] + c + ".csv";
			if (isOpen(text_window))
				close(text_window);
		}
	}
}
