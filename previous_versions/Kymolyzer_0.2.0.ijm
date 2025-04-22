// *******************************************************************
// * title: "Kymolyzer"                                              *
// * author: Jakub Zahumensky; e-mail: jakub.zahumensky@iem.cas.cz   *
// * - Department of Functional Organisation of Biomembranes         *
// * - Institute of Experimental Medicine CAS                        *
// * - citation: https://doi.org/10.1093/biomethods/bpae075          *
// *******************************************************************

version = "0.2.0";
setBatchMode(true);
run("Set Measurements...", "area mean standard modal min integrated centroid fit redirect=None decimal=5");
// for testing, simply uncomment the "test = 1;" line (i.e., delete the "//")
// this changes some things:
// - batchMode does not start, so all intermediary images are shown
// - only a small amount of ROIs is analyzed
//test = false;
test = true;
if (test == true)
	setBatchMode(false);

close("*");

process_choices = newArray("Create kymograms", "Display kymograms", "Analyze kymograms", "EXIT");
var process = "";
interpolation = newArray("None","Bilinear");
var LUTs = newArray(3);
var channels = newArray();
// only files with these extensions will be processed
// if your microscopy images are in a different format, add the extension to the list
extension_list = newArray("czi", "oif", "lif", "tif", "vsi");
var publication = "Zahumensky & Malinsky, 2004; doi: 10.1093/biomethods/bpae075";
var GitHub_microscopy_analysis = "https://github.com/jakubzahumensky/microscopy_analysis";
var GitHub_kymolyzer = "https://github.com/jakubzahumensky/kymolyzer";

var file = "";
var dir_ROIs = "";
var dir_kymograms_main = "";
var dir_kymograms_image = "";
var dir_kymograms_image_raw = "";
var dir_kymograms_image_filtered = "";
var process_channels = newArray();
var channel = "";
var kymogram_list = "";
var kymogram_source_data = "data-processed";
var just_started = true;

subset_default = "";

//initial_folder = "D:/Yeast/EXPERIMENTAL/macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/";
//initial_folder = "/mnt/data/Yeast/EXPERIMENTAL/macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/";
initial_folder = "/home/jakub/Data science/IJ macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/";

cleanUp();
dialogWindow(initial_folder);

function dialogWindow(folder){
	help_message = "<html>"
		+"<center><b>Kymolyzer, version "+ version + "</b></center>"
		+"<center><i>source:" + GitHub_kymolyzer + "</i></center>"
		+"<br>"
		+"<i> This macro requires that ROIs are already defined and named a certain way that corresponds to guidelines in (1). "
		+"It is strongly recommended that the provided 'Correct and project' macro is used to prepare the images first, "
		+"followed by the 'ROI_prep' macro to make the actual ROIs.</i><br>"
		+"<br>"
		+"<b>Create kymograms</b><br>"
		+"Press to create kymograms from defined ROIs. Error is displayed if no ROIs are defined.<br>"
		+"<br>"
		+"<b>Check kymograms</b><br>"
		+"Images in the folder are displayed one-by-one, together with kymograms for each cell (defined ROI).<br>"
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
		Dialog.addString("Subset (optional):", subset_default);
		Dialog.addChoice("Select an operation:", process_choices, process_choices[1]);
		Dialog.setLocation(screenWidth*2.04/3, screenHeight/9.5);
		Dialog.addHelp(help_message);
		Dialog.show();
		folder = replace(Dialog.getString(), "\\", "/");
		channels = sortIDs(Dialog.getString);
		LUTs_string = replace(Dialog.getString(), " ", "");
		LUTs_temp = split(LUTs_string,",,");
		subset = Dialog.getString();
		process = Dialog.getChoice();

	for (i = 0; i < channels.length; i++){
		LUTs[channels[i]-1] = LUTs_temp[i];
	}

	file_counter = 0;
	overwrite_kymograms = false;
	if (process == process_choices[0]){
		kymogram_count = findKymograms(folder, 0, "");
		if (kymogram_count >= 1)
			overwrite_kymograms = getBoolean("Existing kymograms detected. Do you want to overwrite them?");
	}

	processFolder(folder, process, overwrite_kymograms);
	cleanUp();
	dialogWindow(folder);
}


// Definition of "processFolder" function:
// Makes a list of contents of specified folder (folders and files) and goes through it one by one.
// If it finds another directory, it enters it and makes a new list and does the same. In this way, it enters all subdirectories and looks for files.
// If a list item is an image of type specified in the 'extension_list', it runs processFile() with selected process on that image file.
function processFolder(dir, processing_function, overwrite){
    list = getFileList(dir);
    for (i = 0; i < list.length; i++){
        if (endsWith(list[i], "/")){
            processFolder("" + dir + list[i], processing_function, overwrite); // Recursively process subfolders
        } else {
            file = dir + list[i];
//            if (endsWith(dir, image_type + "/data/") && indexOf(file, subset) >= 0){
            if (endsWith(dir, "/" + kymogram_source_data + "/") && indexOf(file, subset) >= 0){
                ext_index = lastIndexOf(file, ".");
	            ext = substring(file, ext_index + 1);
	            if (contains(extension_list, ext)) {
	                title = File.getNameWithoutExtension(file);
	                i = processFile(processing_function, i, overwrite);
	            }
            }
        }
    }
}

// crossroad for processing function based on user selection in dialogWindow() function
function processFile(process, i, overwrite){
    if (matches(process, process_choices[0])){
    	setBatchMode(true);
		createKymograms(overwrite);
    } else if (matches(process, process_choices[1])){
		setBatchMode(false);
		i = displayKymograms(i);
	} else if (matches(process, process_choices[2])){
		if (just_started == true){
			help_message = "<html>"
				+"lorem ipstum";
			Dialog.create("Specify channels to be alanyzed:");
			Dialog.addString("Channels to be analyzed", "");
			Dialog.addHelp(help_message);
			Dialog.show();
			channels_input = Dialog.getString();
			process_channels = sortIDs(channels_input);
			
			just_started = false;
		}

		setBatchMode(true);
		for (c = 0; c < process_channels.length; c++){	
			channel = process_channels[c];
			if (contains(channels, channel))
				analyzeKymograms();
		}	
	} else {
		cleanUp();
		exit("See ya.");
	}
	return i;
}

function prepare(){
	open(file);
	setLocation(0, 0, screenWidth/3, screenWidth/3);
	title = File.nameWithoutExtension;
	rename(title);
	title = cleanTitle(title);
	setLUTs(true);
	dir_ROIs = File.getParent(dir) + "/" + replace(File.getName(dir), kymogram_source_data, "ROIs") + "/";
	if (!File.exists(dir_ROIs))
		exit("Create ROIs before running this macro again, or double-check the data structure if you have defined ROIs previously.");
	dir_kymograms_main = File.getParent(dir) + "/" + replace(File.getName(dir), kymogram_source_data, "kymograms") + "/";
	dir_kymograms_image = dir_kymograms_main + title  + "/";
	dir_kymograms_image_raw = dir_kymograms_image + "raw/";
//	dir_kymograms_image_filtered = dir_kymograms_image + "filtered-ch" + channel + "/";
	dirList = newArray(dir_kymograms_main, dir_kymograms_image, dir_kymograms_image_raw);
	for (j = 0; j < dirList.length; j++)
		if (!File.exists(dirList[j]))
			File.makeDirectory(dirList[j]);
	roiManager("reset");
	roiManager("Open", dir_ROIs + title + "-RoiSet.zip");
	roiManager("Show All with labels");
	roiManager("Remove Channel Info");
}

function createKymograms(overwrite){
// TODO - some renaming magic will need to take place here
// otherwise the ROI handling will be cumbersome and require the user to rename things
// maybe search for SUM/MAX/AVG in ROISet names and remove them?
	prepare();
	numROIs = roiManager("count");
	last = numROIs;
	if (test == true)
		last = 20;
	for (j = 0; j < last; j++) {
		selectWindow(title);
		roiManager("Select", j);
		run("Area to Line");
		run("Reslice [/]...", "output=1.000 start=Top avoid");
	
		// adjust contrast and save kymogram, including a version stretched in y axis to facilitate viewing
		// analysis is performed on "raw" kymograms only
		Stack.setDisplayMode("composite");
		setLUTs(true);
		kymogram_path = dir_kymograms_image_raw + "ROI_" + j + 1;
		if (!File.exists(kymogram_path + ".tif") || overwrite == true)
			saveAs("TIFF", kymogram_path);
		close();
	}
	close(title);
}

function displayKymograms(k){
	prepare();
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
	list_plus = Array.concat(this_img, next_img, prev_img, list);
	display_next = this_img;
	excluded_string = findExcluded(kymogram_path);
	t_stretch = 1;
	grayscale = false;
	while (display_next == this_img){
		Dialog.createNonBlocking("Select ROIs for display:");
		Dialog.addMessage("Current image (" + k+1 + "/" + list.length + "): " + list[k]);
		Dialog.addChoice("Display next:", list_plus, this_img);
		Dialog.addString("Kymograms to display:", 1 + "-" + kymogram_count);
		Dialog.addChoice("Display:", display_options);
//		Dialog.addToSameRow();
		Dialog.addCheckbox("Display in grayscale", grayscale);
		Dialog.addNumber("Stretch in time:", t_stretch);
		Dialog.addMessage("Currently excluded kymograms:" + excluded_string);
		Dialog.addString("Exclude kymograms:", "");
		Dialog.addString("Restore kymograms:", "");
		Dialog.setLocation(screenWidth*2.07/3, screenHeight*6/9);
		Dialog.show();
		display_next = Dialog.getChoice();
		kymogram_IDs = sortIDs(Dialog.getString());
		display_type = Dialog.getChoice();
		grayscale = Dialog.getCheckbox();
		t_stretch = Dialog.getNumber();
		kymograms_to_exclude = sortIDs(Dialog.getString());
		kymograms_to_include = sortIDs(Dialog.getString());

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
			for (l = 0; l < filtered_folders.length; l++){
				kymogram_path = dir_kymograms_image + filtered_folders[l];
				offset = showKymograms(kymogram_path, suffix, offset, 1, grayscale);
			}
		} else {
			for (c = 0; c < channels.length; c++){
				offset = showKymograms(kymogram_path, suffix, offset, channels[c], grayscale);
			}
		}
	}

	close("*");
	if (display_next == prev_img){
		if (k > 0){
			k--;
		} else {
			display_next = this_img;
			waitForUser("This is the first image of the series, there is no previous image.");
		}
	} else if (display_next == next_img){
		k++;
		if (k >= list.length)
			return k-1;
	} else {
		k = getIndex(list, display_next);
	}
	return k-1;
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


function analyzeKymograms(){
	prepare();
	dir_kymograms_image_filtered = dir_kymograms_image + "filtered-ch" + channel + "/";
	if (!File.exists(dir_kymograms_image_filtered))
			File.makeDirectory(dir_kymograms_image_filtered);
	kymogram_list = getFileList(dir_kymograms_image_raw);
	for (j = 0; j < kymogram_list.length; j++){
		kymogram = dir_kymograms_image_raw + kymogram_list[j];
		if (!endsWith(kymogram_list[j], "-excluded.tif")){
			filterKymogramsFourier(kymogram_list[j]);
/* 		 	b = "segment into objects";
				"try using the processing for foci_analyze_particles of tangential images"
				return "segmented objects to be used further, maybe skeletonize to measure length"
			b1 = "measure the length of the objects";
				return length;
			b2 = "measure average speed of the object";
				return "average speed" + "all individual speeds???"
			b3 = "measure mean 'lifetime', i.e., length along y axis (issue - if it's already present, the value makes no sense)";
				return lifetime;
			d = "measure variability along y axis";
				return CV;
			e = "degree of colocalization - overall and something to analyze the possible transient interaction of proteins based on how long they stay colocalized"
				return time_of_coalescence;
				return degree_of_colocalization(Pearson);
*/			
		}
	}

}

function filterKymogramsFourier(kymogram_name){
	x = 3;
	filters = newArray("forward", "backward", "static");
	setForegroundColor(0, 0, 0);
	setBackgroundColor(0, 0, 0);
	open(dir_kymograms_image_raw + kymogram_name);
	Stack.setChannel(channel);
	title = File.nameWithoutExtension();

	run("Gaussian Blur...", "sigma=1");
	getDimensions(width1, height1, img_channels, slices, frames);
	extendBorders();
//	run("Extend Image Borders", "left=width1 right=width1 top=height1 bottom=height1 fill=Mirrored");
//run("Scale...", "x=3 y=3 z=1.0 interpolation=None create");
	rename("extended");
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
			fillRect(0, 0, width/2 + x, height/2 + x);
			fillRect(width/2 - x, height/2 - x, width/2 + x, height/2 + x);	
		} else {
			run("FFT");
			getDimensions(width, height, img_channels, slices, frames);
			makePolygon(0-x, 0, width/2, height/2 + x, width + x, 0);
			run("Clear", "slice");
			makePolygon(0-x, height, width/2, height/2 - x, width + x, height);
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
	close("FFT*");
	close("extended");

	max_0 = 0;
	for (i = 0; i < filters.length; i++){
		selectWindow("FILTERED-" + filters[i]);
		run("Clear Results");
		run("Measure");
		MAX = getResult("Max", 0);
		if (MAX > max_0){
			max_0 = MAX;
		}
	}
	
	LUTs_RGB = newArray("Red", "Green", "Blue");
	for (i = 0; i < filters.length; i++){
		selectWindow("FILTERED-" + filters[i]);
		setMinAndMax(0, max_0*0.95);
		new_title = title + "-";
		run(LUTs_RGB[i]);
		saveAs("TIFF", dir_kymograms_image_filtered + new_title + filters[i]);
		rename("FILTERED-" + filters[i]);
	}

	run("Merge Channels...", "c1=[FILTERED-forward] c2=[FILTERED-backward] c3=[FILTERED-static] create keep ignore");
	saveAs("TIFF", dir_kymograms_image_filtered + new_title + "merged");
	close("FILTERED*");
	close("Results");
	close("*");
}

function contains(array, value){
    for (i = 0; i < array.length; i++)
        if (array[i] == value)
        	return true;
    return false;
}

function getIndex(array, value){
    for (i = 0; i < array.length; i++)
        if (array[i] == value)
        	return i;
    return "not in array";
}

function getFiles(path){
	list = getFileList(path);
	for (i = list.length-1 ; i >= 0 ; i--){
		if (endsWith(list[i], "/"))
			list = Array.deleteIndex(list, i);
	}
	return list;
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

function cleanUp(){
	windows_list = newArray("ROI manager", "Log", "Results", "Debug");
	for (i = 0; i < windows_list.length; i++){
		if (isOpen(windows_list[i]))
			close(windows_list[i]);
	}
	close("ROI manager");
	close("*");
}

function setLUTs(enhance){
	for (i = 0; i < channels.length; i++){
		Stack.setChannel(channels[i]);
		run(LUTs[i]);
		if (enhance == true)
			run("Enhance Contrast", "saturated=0.01");
	}
}

function cleanTitle(string){
	suffixes = newArray("-AVG", "-SUM", "-MAX", "-MIN", "-processed", "-corr");
	for (i = 0; i < suffixes.length; i++){
		string = replace(string, suffixes[i], "");
	}
	return string;
}

function printArray(array){
	for (i = 0; i < array.length; i++){
		print(array[i]);
	}
	print("********");
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
