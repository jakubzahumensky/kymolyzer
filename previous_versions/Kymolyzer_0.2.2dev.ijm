/* title: "Kymolyzer"
 * author: Jakub Zahumensky
 * - e-mail: jakub.zahumensky@iem.cas.cz
 * - e-mail: jakub.zahumensky@gmail.com
 * - GitHub: https://github.com/jakubzahumensky
 * - Department of Functional Organisation of Biomembranes
 * - Institute of Experimental Medicine CAS
 * - citation: https://doi.org/10.1093/biomethods/bpae075
 *
 * Summary:
 * This macro takes microscopy time-series corrected for drift and/or bleaching calculates kymograms and analyzes them.
 * The analysis includes fitlering of main directions and calculation of several quantification parameters, such as speed of particles,
 * variation of signal etc. The calculation of kymograms requires ROIs. These can be prepared either autiomatically, using the approach
 * described in https://doi.org/10.1093/biomethods/bpae075, or manually using the procided option in this macro.
 *
 * Abbreviations:
 * CV - coefficient of variance
 */

macro_name = "Kymolyzer";
version = "0.2.2dev";

/* for testing, simply uncomment the "test = true;" line (i.e., delete the "//")
 * - batchMode does not start, so all intermediary images are shown
 * - only a small amount of ROIs is used/analyzed
 */
test = false;
//test = true;
last_ROI_test = 4;
if (test == false)
	setBatchMode(true);

/* Definitions of variables and constatns used in the macro below. */
publication = "Zahumensky & Malinsky, 2004; doi: 10.1093/biomethods/bpae075";
GitHub_microscopy_analysis = "https://github.com/jakubzahumensky/microscopy_analysis";
GitHub_kymolyzer = "https://github.com/jakubzahumensky/kymolyzer";
extension_list = newArray("czi", "oif", "lif", "tif", "vsi"); // only files with these extensions will be processed
process_choices = newArray("Draw ROIs", "Create kymograms", "Display kymograms", "Filter kymograms", "Analyze kymograms", "EXIT");
filters = newArray("forward", "backward", "static");
interpolation = newArray("None","Bilinear");
kymogram_source_data = "data-processed";
RoiSet_suffix = "-RoiSet.zip";
initial_folder = "";
initial_folder = "D:/Yeast/EXPERIMENTAL/macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/";
//initial_folder = "D:/Yeast/EXPERIMENTAL/microscopy/JZ-M-072-241002 - PM transporter localization and kinetics - CzBI (Olga)/250411 - Nha1, Trk1/";
//initial_folder = "/mnt/data/Yeast/EXPERIMENTAL/macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/";
//initial_folder = "/home/jakub/Data science/IJ macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/";

var file = "";
var dir_ROIs = "";
var dir_kymograms_main = "";
var dir_kymograms_image = "";
var dir_kymograms_image_raw = "";
var dir_kymograms_image_filtered = "";
var channels_to_analyze = newArray();
var current_channel = "";
var kymogram_list = "";
var process = "";
var process_ID = -1;
var LUTs = newArray(3);
var channels = newArray();

var temporary_results_file = "";
var processed_images = "";

var naming_scheme = "";
var experiment_scheme = "";
var subset = "";

var just_started = true;
var background = 0;
var average_speeds = newArray(3);

closeAllWindows();
initialDialogWindow(initial_folder);

function initialDialogWindow(folder){
	help_message = "<html>"
		+"<center><b>Kymolyzer, version " + version + "</b></center>"
		+"<center><i>source:" + GitHub_kymolyzer + "</i></center>"
		+"<br>"
		+"<i> This macro requires that ROIs are already defined and named a certain way that corresponds to guidelines in (1). "
		+"It is strongly recommended that the provided 'Correct and project' macro is used to prepare the images first, "
		+"followed by the 'ROI_prep' macro to make the actual ROIs.</i><br>"
		+"<br>"
		+"<b>Draw ROIs</b><br>"
		+"Press to manually create ROIs for your images.<br>"
		+"<br>"
		+"<b>Create kymograms</b><br>"
		+"Press to create kymograms from defined ROIs. Error is displayed if no ROIs are defined.<br>"
		+"<br>"
		+"<b>Display kymograms</b><br>"
		+"Images in the folder are displayed one-by-one, together with kymograms for each cell (defined ROI).<br>"
		+"<br>"
		+"<b>Filter kymograms</b><br>"
		+"Kymograms are fitlered using Fourier transformations into dominant directions: backward, forward, statis.<br>"
		+"<br>"
		+"<b>Analyze kymograms</b><br>"
		+"Kymograms are quantified. Results are saved in a csv file that can be further processed using <i>R scripts</i> published previously (1, 2).<br>"
		+"<br>"
		+"<b>References:</b><br>"
		+"(1) " + publication + "<br>"
		+"(2) " + GitHub_microscopy_analysis + "<br>";
	Dialog.createNonBlocking("Kymolyzer");
		Dialog.addDirectory("Directory:", folder);
		Dialog.addString("Channels for kymograms", "1, 2", 5);
		Dialog.addString("Channel display:", "Magenta, Cyan", 20);
		Dialog.addString("Subset (optional):", "");
		Dialog.addChoice("Select an operation:", process_choices, process_choices[process_ID + 1]);
		Dialog.setLocation(screenWidth*2.2/3, screenHeight/9.5);
		Dialog.addHelp(help_message);
		Dialog.show();
		folder = fixFolderInput(Dialog.getString());
		channels = sortIDs(Dialog.getString());
		LUTs = sortLUTs(Dialog.getString());
		subset = Dialog.getString();
		process = Dialog.getChoice();

	dir_master = folder; // folder into which Results summary is saved; it is the same folder as is used by the user as the starting point
	process_ID = getArrayIndex(process_choices, process); // get index of seelcted process (enables automatic preselection of subsequent step in the dialog window)
	processFolder(folder, process); // process all files in all folders recursively
	if (matches(process, process_choices[4])) /* "Analyze kymograms" */
		wrapUp();
	initialDialogWindow(folder);
}

/* Convert backslash to slash in the folder path, append a slash at the end,
 *  and if analysis is run from within the data folder, move one level up.
 *  These fixes are requird for the macro to work properly.
 */
function fixFolderInput(folder_input){
	folder_fixed = replace(folder_input, "\\", "/");
	if (!endsWith(folder_fixed, "/"))
		folder_fixed = folder_fixed + "/";
	if (indexOf(File.getName(folder_input), "data") == 0)
		folder_fixed = File.getParent(folder_fixed) + "/";
	return folder_fixed;
}

/* remove empty spaces, split into an array and sort LUTs input into an array,
 *  in an order corresponding to the channels input.
 *  LUTS (Array) is a global variable.
 */
function sortLUTs(LUTs_input){
	LUTs_input = replace(LUTs_input, " ", "");
	LUTs_input = split(LUTs_input,",,");
	LUTs_sorted = newArray();
	for (i = 0; i < channels.length; i++){
		LUTs_sorted[channels[i]-1] = LUTs_input[i];
	}
	return LUTs_sorted;
}

/* Makes a list of contents of specified folder (folders and files) and goes through it one by one.
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
			if (endsWith(dir, "/" + kymogram_source_data + "/") && indexOf(file, subset) >= 0){
				ext_index = lastIndexOf(file, ".");
				ext = substring(file, ext_index + 1);
				if (contains(extension_list, ext)) {
					title = File.getNameWithoutExtension(file);
					i = processFile(processing_function, i);
				}
			}
		}
	}
}

/* crossroad for processing function based on user selection in initialDialogWindow() function */
function processFile(process, i){
	if (matches(process, process_choices[0])){ /* "Draw ROIs" */
		setBatchMode(false);
		drawROIs();
		setBatchMode(true);
	} else if (matches(process, process_choices[1])){ /* "Create kymograms" */
		createKymograms();
	} else if (matches(process, process_choices[2])){ /* "Display kymograms" */
		setBatchMode(false);
		i = displayKymograms(i);
		setBatchMode(true);
	} else if (matches(process, process_choices[3])){ /* "Filter kymograms" */
		filterKymograms();
	} else if (matches(process, process_choices[4])){ /* "Analyze kymograms" */
		startAnalysis();
	} else { /* "EXIT" */
		closeAllWindows();
		exit();
	}
	return i;
}

function drawROIs(){
	clean_title = prepareImage();
	prepareROIs(clean_title);
	setTool("ellipse");
	waitForUser("Make ROIs by drawing them and pressing 't' (or press the 'Add [t]' a button in the ROI manager)\n after each to add them to the ROI manager.");
	roiManager("Remove Channel Info");
	roiManager("Remove Slice Info");
	roiManager("Remove Frame Info");
	roiManager("Save", dir_ROIs + clean_title + RoiSet_suffix);
	close("*");
}

function createKymograms(){
	clean_title = prepareImage();
	prepareKymogramDirs(clean_title);
	num_of_ROIs = prepareROIs(clean_title);
	last_ROI = num_of_ROIs;
	if (test == true)
		last_ROI = last_ROI_test;
	for (j = 0; j < last_ROI; j++) {
		selectWindow(title);
		roiManager("Select", j);
		run("Area to Line");
		run("Reslice [/]...", "output=1.000 start=Top avoid");
		Stack.setDisplayMode("composite");
		setLUTs(true);
		kymogram_path = dir_kymograms_image_raw + "ROI_" + j + 1;
		saveAs("TIFF", kymogram_path);
		close();
	}
	close(title);
}

function displayKymograms(k){
	clean_title = prepareImage();
	prepareKymogramDirs(clean_title);
	num_of_ROIs = prepareROIs(clean_title);
	this_img = "> this image <";
	next_img = "-> next image";
	prev_img = "<- previous image";
	fourier_filters = newArray("FILTERED-forward", "FILTERED-backward", "FILTERED-static", "FILTERED-merged");
	display_options = newArray("regular");
	if (findKymograms(dir_kymograms_main, 0, "-merged.tif") > 0)
		display_options = Array.concat(display_options, fourier_filters);
	kymogram_path = dir_kymograms_image_raw;
	kymogram_list = getFiles(kymogram_path);
	kymogram_count = kymogram_list.length;
	kymogram_IDs_string = "" + 1 + "-" + kymogram_count;
	list_plus = Array.concat(this_img, next_img, prev_img, list, "EXIT");
	display_next = this_img;
	excluded_string = findExcluded(kymogram_path);
	display_type = "regular";
	t_stretch = 1;
	grayscale = false;

	while (display_next == this_img){
		Dialog.createNonBlocking("Select ROIs for display:");
			Dialog.addMessage("Current image (" + k+1 + "/" + list.length + "): " + list[k]);
			Dialog.addChoice("Display next:", list_plus, this_img);
			Dialog.addString("Kymograms to display:", kymogram_IDs_string);
			Dialog.addChoice("Display:", display_options, display_type);
			Dialog.addCheckbox("Display in grayscale", grayscale);
			Dialog.addNumber("Stretch in time:", t_stretch);
			Dialog.addMessage("Currently excluded kymograms:" + excluded_string);
			Dialog.addString("Exclude kymograms:", "");
			Dialog.addString("Restore kymograms:", "");
			Dialog.setLocation(screenWidth*2.2/3, screenHeight*5.5/9);
			Dialog.show();
			display_next = Dialog.getChoice();
			kymogram_IDs_string = Dialog.getString();
			display_type = Dialog.getChoice();
			grayscale = Dialog.getCheckbox();
			t_stretch = Dialog.getNumber();
			kymograms_to_exclude = sortIDs(Dialog.getString());
			kymograms_to_include = sortIDs(Dialog.getString());
		kymogram_IDs = sortIDs(kymogram_IDs_string);

		close("ROI*");
		if (display_next != this_img)
			break;

		kymogram_path = dir_kymograms_image_raw;
		suffix = ".tif";
		if (kymograms_to_exclude.length > 0)
			excludeKymograms(kymograms_to_exclude, "exclude");
		if (kymograms_to_include.length > 0)
			excludeKymograms(kymograms_to_include, "include");
		excluded_string = findExcluded(dir_kymograms_image_raw);
		excluded_array = sortIDs(excluded_string);
		offset = screenHeight/9;

		if (contains(fourier_filters, display_type)){
			suffix = replace(display_type, "FILTERED", "") + suffix;
			kymofolders = getFileList(dir_kymograms_image);
			filtered_folders = newArray();
			for (j = 0; j < kymofolders.length; j++){
				if (startsWith(kymofolders[j], "filtered"))
					filtered_folders = Array.concat(filtered_folders, kymofolders[j]);
			}
			// cycling through available channels
			for (c = 0; c < filtered_folders.length; c++){
				kymogram_path = dir_kymograms_image + filtered_folders[c];
				offset = showKymograms(kymogram_path, suffix, offset, 1, grayscale);
			}
		} else {
			for (c = 0; c < channels.length; c++){
				offset = showKymograms(kymogram_path, suffix, offset, channels[c], grayscale);
			}
		}
	}
	close("*");
	k = next_image_index(display_next, k);
	return k-1;
}

function next_image_index(next, index){
	if (next == prev_img){
		if (index == 0) // displayed image is the first in the current folder
			waitForUser("This is the first image of the series, there is no previous image.");
		else
			index--;
	} else if (next == next_img){
		index++;
		if (index >= list.length)
			return index-1;
	} else { // if a spesific image is chosen from the list, its index needs to be found
		index = getArrayIndex(list, next);
	}
	return index;
}

function prepareROIs(img_title){
	roiManager("reset");
	dir_ROIs = File.getParent(dir) + "/" + replace(File.getName(dir), kymogram_source_data, "ROIs") + "/";
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

function getFiles(path){
	list = getFileList(path);
	for (i = list.length-1 ; i >= 0 ; i--){
		if (endsWith(list[i], "/"))
			list = Array.deleteIndex(list, i);
	}
	return list;
}

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

function excludeKymograms(list, operation){
	for (i = 0; i < list.length; i++){
		if (operation == "exclude"){
			old_name = kymogram_path + "ROI_" + list[i] + ".tif";
			new_name = replace(old_name, ".tif", "-excluded.tif");
		} else if (operation == "include"){
			old_name = kymogram_path + "ROI_" + list[i] + "-excluded.tif";
			new_name = replace(old_name, "-excluded", "");
		}
		File.rename(old_name, new_name);
		close("Log");
	}
}

function showKymograms(kymogram_path, suffix, offset_y, ch, display_in_grayscale){
	offset_x = screenWidth/3;
	for (j = 0; j < kymogram_IDs.length; j++){
		kymogram = kymogram_path + "ROI_" + kymogram_IDs[j] + suffix;
		if (!contains(excluded_array, kymogram_IDs[j]) && File.exists(kymogram)){
			open(kymogram);
			getDimensions(w, h, kymogram_channels, s, f);
			if (ch <= kymogram_channels){
				kymo_title = getTitle();
				if (t_stretch > 1){
					run("Scale...", "x=1.0 y=" + t_stretch + ".0 z=1.0 depth=2 interpolation=Bilinear average create");
					rename(kymo_title + "-stretched");
					close(kymo_title);
				}
				if (suffix != "-merged.tif"){
					if (kymogram_channels > 1){
						Stack.setDisplayMode("color");
						Stack.setChannel(ch);
					}
					if (display_in_grayscale == true){
						run("Grays");
					} else if (suffix == ".tif"){
						run(LUTs[ch-1]);
					}
				}
				setLocation(offset_x, offset_y);
				run("View 100%");
				getLocationAndSize(x, y, kymogram_width, kymogram_height);
				offset_x += kymogram_width;
				if (offset_x + kymogram_width >= screenWidth){
					offset_x = screenWidth/3;
					offset_y += kymogram_height;
				}
			} else {
				getLocationAndSize(x, y, kymogram_width, kymogram_height);
				close();
				j = kymogram_IDs.length;
			}
		}
	}
	return offset_y + kymogram_height;
}

function contains(array, value){
	for (i = 0; i < array.length; i++)
		if (array[i] == value)
			return true;
	return false;
}

/* Filter kymograms into dominant directions and save the resulting images. These are later used to calculate average speeds of traces.
 * The approach and function in based on, with modifications:
 * Mangeol P, Prevo B, Peterman EJ.
 * KymographClear and KymographDirect: two tools for the automated quantitative analysis of molecular and cellular dynamics using kymographs.
 * Mol Biol Cell. 2016;27(12):1948-1957. doi:10.1091/mbc.E15-06-0404
*/
function filterKymograms(){
	for (c = 1; c <= 3; c++){
		current_channel = c;
		if (contains(channels, current_channel)){
			clean_title = prepareImage();
			prepareKymogramDirs(clean_title);
			dir_kymograms_image_filtered = dir_kymograms_image + "filtered-ch" + current_channel + "/";
			if (!File.exists(dir_kymograms_image_filtered))
				File.makeDirectory(dir_kymograms_image_filtered);
			kymogram_list = getFileList(dir_kymograms_image_raw);
			for (j = 0; j < kymogram_list.length; j++){
				kymogram = dir_kymograms_image_raw + kymogram_list[j];
				if (!endsWith(kymogram, "-excluded.tif")){
					open(kymogram);
					kymogram_title = File.nameWithoutExtension();
					rename(kymogram_title);
					Stack.setChannel(current_channel);
					findMainDirections(kymogram_title);
					saveFilteredKymograms(kymogram_title);
				}
			close("*");
			}
		}
	}
}

function findMainDirections(kymogram_image_name){
	crop_factor = 3;
	setForegroundColor(0, 0, 0);
	setBackgroundColor(0, 0, 0);
	run("Gaussian Blur...", "sigma=1");
	getDimensions(width1, height1, img_channels, slices, frames);
	extendBorders();
	run("16-bit");
	for (i = 0; i < filters.length; i++){
		selectWindow("extended");
		run("Duplicate...", "title=[" + filters[i] + "]");
		selectWindow(filters[i]);
		if (i != 2){
			if (i == 1)
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
		if (i == 1)
			run("Flip Horizontally");
		makeRectangle(width1, height1, width1, height1);
		run("Crop");
		rename("FILTERED-" + filters[i]);
		close(filters[i]);
	}
}

function extendBorders(){
	run("Duplicate...", "title=DUP");
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

function saveFilteredKymograms(kymogram_image_name){
	max_0 = 0;
	for (i = 0; i < filters.length; i++){
		selectWindow("FILTERED-" + filters[i]);
		getStatistics(area, mean, min, max, std, histogram);
		if (max > max_0){
			max_0 = max;
		}
	}
	LUTs_RGB = newArray("Red", "Green", "Blue");
	for (i = 0; i < filters.length; i++){
		selectWindow("FILTERED-" + filters[i]);
		setMinAndMax(0, max_0*0.95);
		run(LUTs_RGB[i]);
		saveAs("TIFF", dir_kymograms_image_filtered + kymogram_image_name + "-" + filters[i]);
		rename("FILTERED-" + filters[i]);
	}
	run("Merge Channels...", "c1=[FILTERED-forward] c2=[FILTERED-backward] c3=[FILTERED-static] create keep ignore");
	saveAs("TIFF", dir_kymograms_image_filtered + kymogram_image_name + "-merged");
}

function startAnalysis(){
	if (just_started == true){
		help_message = "<html>"
			+"<b>Channel(s)</b><br>"
			+"Specify image channel(s) to be processed. Use comma(s) to specify multiple channels or a dash to specify a range.<br>"
			+"<br>"
			+"<b>Naming scheme</b><br>"
			+"Specify how your files are named (without extension). Results are reported in a comma-separated table, with the parameters specified here used as column headers. "
			+"The default \"<i>strain,medium,time,condition,frame</i>\" creates 5 columns, with titles \"strains\", \"medium\" etc. "
			+"Using a consistent naming scheme across your data enables automated downstream data processing.<br>"
			+"<br>"
			+"<b>Experiment code scheme</b><br>"
			+"Specify how your experiments are coded. The macro assumes a folder structure of <i>\".../experimental_code/biological_replicate_date/image_type/data/\"</i>. See protocol for details.<br>"
			+"<br>"
			+"<b>Subset</b><br>"
			+"If used, only images with filenames containing specified <i>string</i> (i.e., group of characters and/or numbers) will be processed. "
			+"This option can be used to selectively process images of a specific strain, condition, etc. "
			+"Leave empty to process all images in specified directory (and its subdirectories).<br>"
			+"</html>";
		Dialog.create("Specify channels to be alanyzed:");
			Dialog.addString("Channels to be analyzed", "1-2");
			Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);
			Dialog.addString("Experiment code scheme:", "XY-M-000", 33);
			Dialog.addString("Subset (optional):", "");
			Dialog.addCheckbox("Continue previous analysis:", true);
			Dialog.addHelp(help_message);
			Dialog.show();
			channels_input = Dialog.getString();
			naming_scheme = Dialog.getString();
			experiment_scheme = Dialog.getString();
			subset = Dialog.getString();
			continue_analysis = Dialog.getCheckbox();
		channels_to_analyze = sortIDs(channels_input);
		just_started = false;
	}
	for (c = 0; c < channels_to_analyze.length; c++){
		current_channel = channels_to_analyze[c];
		if (contains(channels, current_channel)){
			temporary_results_file = "results-temporary_channel_" + current_channel + ".csv";
			processed_images_file = "processed_images_channel_" + current_channel + ".csv";
			if (!isOpen(temporary_results_file))
				initializeAnalysis(temporary_results_file, processed_images_file);
			if (File.exists(dir_master + processed_images_file))
				processed_images = File.openAsString(dir_master + processed_images_file);
			if (indexOf(processed_images, file) < 0)
				analyzeKymograms(temporary_results_file, processed_images_file);
		}
	}
}

// create new text windows to write temporary results, names of processed files and files without defined ROIs
function initializeAnalysis(temp_res_file, proc_imgs_file){
	column_width = screenWidth/channels_to_analyze.length;
	run("Text Window...", "name=[" + temp_res_file + "] width=96 height=32");
	setLocation((current_channel - 1)*column_width, 0);
	run("Text Window...", "name=[" + proc_imgs_file + "] width=96 height=32");
	setLocation((current_channel - 1)*column_width, screenHeight/2);
	if (continue_analysis == true && File.exists(dir_master + temp_res_file)){ // if File.exists() - when the analysis is continued and multiple channels are selected, some may not have temporary files
		print("[" + temp_res_file + "]", File.openAsString(dir_master + temp_res_file));
		proc_imgs_list = File.openAsString(dir_master + proc_imgs_file);
		print("[" + proc_imgs_file + "]", proc_imgs_list);
	} else {
		getDateAndTime(start_year, start_month, start_dayOfWeek, start_dayOfMonth, start_hour, start_minute, start_second, start_msec);
		// print the header of the Results output file
		// the first couple of lines give a general overview of the analysis run
		print("[" + temp_res_file + "]","# Basic macro run statistics:" + "\n");
		print("[" + temp_res_file + "]","# Macro name: " + macro_name + "\n");
		print("[" + temp_res_file + "]","# Macro version: " + version + "\n");
		print("[" + temp_res_file + "]","# Date and time: " + start_year + "-" + String.pad(start_month + 1,2) + "-" + String.pad(start_dayOfMonth,2) + " " + String.pad(start_hour,2) + ":" + String.pad(start_minute,2) + ":" + String.pad(start_second,2)+"\n");
		print("[" + temp_res_file + "]","# Channel: " + current_channel + "\n");
		print("[" + temp_res_file + "]","#" + "\n"); // empty line that is ignored in bash and R
		column_names = "exp_code,BR_date,"
			+ naming_scheme + ",mean_background,cell_no"
			+ ",mean_speed_forward,mean_speed_backward,mean_speed_static,CV";
		print("[" + temp_res_file + "]", column_names + "\n");
	}
}

function analyzeKymograms(res_file, proc_file){
	clean_title = prepareImage();
	prepareKymogramDirs(clean_title);
	background = measureImageBackground(title);
	kymogram_list = getFileList(dir_kymograms_image_raw);
	for (j = 0; j < kymogram_list.length; j++){
		kymogram = dir_kymograms_image_raw + kymogram_list[j];
		if (!endsWith(kymogram, "-excluded.tif")){
			open(kymogram);
			kymogram_title = File.nameWithoutExtension();
			rename(kymogram_title);
			Stack.setChannel(current_channel);
			CV = analyzeCorrelation(kymogram_title);
			for (k = 0; k <= 2; k++){
				filtered_image = dir_kymograms_image_filtered + kymogram_title + "-" + filters[k] + ".tif";
				average_speeds[k] = calculateAverageSpeed(filtered_image);
//				return also "all individual speeds???"
			}

/*
			e = "degree of colocalization - overall and something to analyze the possible transient interaction of proteins based on how long they stay colocalized"
				return time_of_coalescence;
				return degree_of_colocalization(Pearson);
*/
			parents = findParentDirs(); // [0] - experiment code, [1] - biological replicate date
			kymogram_results = parents[0] + "," + parents[1] // [0] - experiment code, [1] - biological replicate date
				+ "," + replace(title," ","_") + "," + background + "," + (j+1) // image title, background intensity and current ROI number
				+ "," + average_speeds[0] + "," + average_speeds[1] + "," + average_speeds[2] + "," + CV;
			print("["+ res_file +"]", kymogram_results + "\n");
		}
	}
	saveTemp(res_file, proc_file);
}

// close all open image windows and specific text windows that might be open
function closeAllWindows(){
	close("*");
	windows_list = newArray("ROI manager", "Log", "Results", "Debug");
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

function prepareImage(){
	open(file);
	setLocation(0, 0, screenWidth/3, screenWidth/3);
	img_title = File.nameWithoutExtension;
	rename(img_title);
	img_title_clean = cleanTitle(img_title);
	setLUTs(true);
	return img_title_clean;
}

function cleanTitle(string){
	suffixes = newArray("-AVG", "-SUM", "-MAX", "-MIN", "-processed", "-corr");
	for (i = 0; i < suffixes.length; i++){
		string = replace(string, suffixes[i], "");
	}
	return string;
}

function setLUTs(enhance){
	for (i = 0; i < channels.length; i++){
		Stack.setChannel(channels[i]);
		run(LUTs[i]);
		if (enhance == true)
			run("Enhance Contrast", "saturated=0.01");
	}
}

function prepareKymogramDirs(clean_title){
	dir_kymograms_main = File.getParent(dir) + "/" + replace(File.getName(dir), kymogram_source_data, "kymograms") + "/";
	dir_kymograms_image = dir_kymograms_main + clean_title  + "/";
	dir_kymograms_image_raw = dir_kymograms_image + "raw/";
	dir_kymograms_image_filtered = dir_kymograms_image + "filtered-ch" + current_channel + "/";
	dirList = newArray(dir_kymograms_main, dir_kymograms_image, dir_kymograms_image_raw);
	for (j = 0; j < dirList.length; j++){
		if (!File.exists(dirList[j]))
			File.makeDirectory(dirList[j]);
	}
}

function analyzeCorrelation(kymogram_image_name){
	line_width = 3;
	run("Line Width...", "line=" + line_width);
	getDimensions(width, height, CH, S, F);
	CV_array = newArray();
	tau_array = newArray();
	for (x = 1; x < width-1; x++){
		selectWindow(kymogram_image_name);
		makeLine(x, 0, x, height-1);
		intensity_profile = getProfile();

		Array.getStatistics(intensity_profile, min, max, mean, stdDev);
		CV_array = Array.concat(CV_array, stdDev/(mean - background));

//		autoCorrelation(intensity_profile);
//		tau = autoCorrelation(intensity_profile);
//		tau_array = Array.concat(tau_array, tau);
	}
	Array.getStatistics(CV_array, min, max, CV_mean, stdDev);
//	Array.getStatistics(tau_array, min, max, tau_mean, stdDev);
//	close(kymogram_image_name);
//	return newArray(CV_mean, tau_mean);
	return CV_mean;
}

function autoCorrelation(I_profile){
	Array.getStatistics(I_profile, I_min, I_max, I_mean, I_stdDev);
	autocorrelation_function = newArray();
	for (tau = 0; tau < I_profile.length; tau++){
		temp_array = newArray();
		for (t = 0; t < I_profile.length - tau; t++){
			temp_array[t] = (I_profile[t] - background)*(I_profile[t+tau] - background);
		}
		Array.getStatistics(temp_array, temp_min, temp_max, temp_mean, temp_stdDev);
		autocorrelation_function[tau] = temp_mean / pow(I_mean - background, 2) - 1;
//		autocorrelation_function[tau] = temp_mean / pow(I_mean - background, 2);
	}
//	Array.print(autocorrelation_function);
	x_axis = Array.getSequence(autocorrelation_function.length);
	Plot.create("Title", "X-axis Label", "Y-axis Label", x_axis, autocorrelation_function);
	Plot.show();
	Plot.freeze(true);
//	return halflife;
}

function calculateAverageSpeed(image){
	open(image);
	run("Duplicate...", "title=DUP");
	run("Normalize Local Contrast", "block_radius_x=30 block_radius_y=30 standard_deviations=3 center stretch");
	run("Bandpass Filter...", "filter_large=40 filter_small=1 suppress=None tolerance=5 autoscale saturate");
	getPixelSize(unit, pixelWidth, pixelHeight);
	bit_depth = bitDepth();
	getStatistics(area, mean, min, max, std, histogram);
	threshold_min = (min + max)/2;
	threshold_max = pow(2, bit_depth) - 1;
	setOption("BlackBackground", true);
	setThreshold(threshold_min, threshold_max, "raw");
	run("Convert to Mask");
	run("Skeletonize");
	run("Analyze Skeleton (2D/3D)", "prune=none show");
	close("Results");
	Table.rename("Branch information", "Results");
	speeds = newArray;
	for (i = 0; i < nResults; i++){
		length = getResult("Branch length", i);
		if (length > pixelWidth/2){
			Delta_x = getResult("V2 x", i) - getResult("V1 x", i);
			Delta_y = getResult("V2 y", i) - getResult("V1 y", i);
			speed = Delta_x/Delta_y;
			if (-"Infinity" < speed && speed < "Infinity")
				speeds = Array.concat(speeds, speed);
		}
	}
	close("Results");
	close("*");
	Array.getStatistics(speeds, min, max, speed_mean, stdDev);
	return speed_mean;
}

function getArrayIndex(array, value){
	for (i = 0; i < array.length; i++)
		if (array[i] == value)
			return i;
	return "not in array";
}

function sortIDs(string){
	// if a range is defined, use the lower number as the beginning and the higher as end value; create an array containing these and all integer numbers between them
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

// To get an estimate of the image background, the background is subtracted in the original image using brute force (rolling ball approach).
// The result is then subtracted from the original image, creating an image of the background.
// The mean intensity of this image is then used as background intensity estimate.
function measureImageBackground(image_title){
	selectWindow(image_title);
	getDimensions(width, height, image_channels, slices, frames);
	run("Duplicate...", "duplicate channels=" + current_channel);
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
	run("Subtract Background...", "rolling=" + width + " stack");
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-background");
	getStatistics(area, mean, min, max, std, histogram);
	selectWindow("DUP-CROP");
	setThreshold(0, mean);
	run("Create Selection");
	// the mean intensity is measured as the background estimate for the raw image and returned by the function
	getStatistics(area, image_background, min, max, std, histogram);
	close("DUP-*");
	close("Result*");
	return image_background;
}

// save the output in csv format and clean the Fiji (ImageJ) space to make it ready for the quantification of the next channel (if applicable)
function wrapUp(){
	for (c = 0; c < channels_to_analyze.length; c++){
		current_channel = channels_to_analyze[c];
		temporary_results_file = "results-temporary_channel_" + current_channel + ".csv";
		processed_images_list = "processed_images_channel_" + current_channel + ".csv";
		if (isOpen(temporary_results_file)){
			getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
			res = "Results of kymogram analysis, channel " + current_channel + " (" + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + "," + String.pad(hour,2) + "-" + String.pad(minute,2) + "-" + String.pad(second,2) + ").csv";
			selectWindow(temporary_results_file);
			saveAs("Text", dir_master + res);
			close("Results");
			close("ROI manager");
			print("[" + res + "]", "\\Close");
		}
		File.delete(dir_master + temporary_results_file);
		print("[" + processed_images_list + "]", "\\Close");
		close("Log");
	}
}

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

function saveTemp(temporary_results_file, temp_proc_file){
	selectWindow(temporary_results_file);
	saveAs("Text", dir_master + temporary_results_file);
	print("[" + temp_proc_file + "]", file + "\n");
	selectWindow(temp_proc_file);
	saveAs("Text", dir_master + temp_proc_file);
}
