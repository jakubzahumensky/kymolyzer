version = "0.1.3";
setBatchMode(true);

//test = false;
test = true;
if (test == true)
	setBatchMode(false);

close("*");

process_choices = newArray("Create kymograms", "Display kymograms", "Analyze kymograms", "EXIT");
interpolation = newArray("None","Bilinear");
var LUTs = newArray("Magenta","Cyan");
// only files with these extensions will be processed
// if your microscopy images are in a different format, add the extension to the list
extension_list = newArray("czi", "oif", "lif", "tif", "vsi");
var publication = "Zahumensky & Malinsky, 2004; doi: 10.1093/biomethods/bpae075";
var GitHub_microscopy_analysis = "https://github.com/jakubzahumensky/microscopy_analysis";
var GitHub_kymolyzer = "https://github.com/jakubzahumensky/kymolyzer";

var file = "";
var roi_dir = "";
var kymo_dir = "";
var kymo_dir_image = "";
var kymo_dir_image_scaled = "";
var kymo_source_data = "data-processed";

subset_default = "";
//initial_folder = "D:/Yeast/EXPERIMENTAL/macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/230413/";
initial_folder = "D:/Yeast/EXPERIMENTAL/macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/";

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
		Dialog.addString("Channel 1 display:", LUTs[0]);
		Dialog.addString("Channel 2 display:", LUTs[1]);
		Dialog.addString("Subset (optional):", subset_default);
//		Dialog.addChoice("Select an operation:", process_choices, process_choices[0]);
		Dialog.addChoice("Select an operation:", process_choices, process_choices[1]);
		Dialog.setLocation(screenWidth*2.04/3, screenHeight/9.5);
		Dialog.addHelp(help_message);
		Dialog.show();
		folder = replace(Dialog.getString(), "\\", "/");
		LUTs[0] = Dialog.getString();
		LUTs[1] = Dialog.getString();
		subset = Dialog.getString();
		process = Dialog.getChoice();

	overwrite_kymograms = false;
	if (process == process_choices[0]){
		kymogram_count = findKymograms(folder, 0);
		if (kymogram_count >= 1)
			overwrite_kymograms = getBoolean("Existing kymograms detected. Do you want to overwrite them?");
	}

	processFolder(folder, process, overwrite_kymograms);
	cleanUp();
	dialogWindow(folder);
}

function processFolder(dir, processing_function, overwrite){
    list = getFileList(dir);
    for (i = 0; i < list.length; i++){
        if (endsWith(list[i], "/")){
            processFolder("" + dir + list[i], processing_function, overwrite); // Recursively process subfolders
        } else {
            file = dir + list[i];
//            if (endsWith(dir, image_type + "/data/") && indexOf(file, subset) >= 0){
            if (endsWith(dir, "/" + kymo_source_data + "/") && indexOf(file, subset) >= 0){
                ext_index = lastIndexOf(file, ".");
	            ext = substring(file, ext_index + 1);
	            if (contains(extension_list, ext)) {
	                title = File.getNameWithoutExtension(file);
	                i = selectProcess(processing_function, i, overwrite);
	            }
            }
        }
    }
}

function selectProcess(process, i, overwrite){
    if (matches(process, process_choices[0])){
    	setBatchMode(true);
		createKymograms(overwrite);
    } else if (matches(process, process_choices[1])){
		setBatchMode(false);
		i = displayKymograms(i);
	}
	else if (matches(process, process_choices[2]))
		analyzeKymograms();
	else {
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
	roi_dir = File.getParent(dir) + "/" + replace(File.getName(dir), kymo_source_data, "ROIs") + "/";
	if (!File.exists(roi_dir))
		exit("Create ROIs before running this macro again, or double-check the data structure if you have defined ROIs previously.");
	kymo_dir = File.getParent(dir) + "/" + replace(File.getName(dir), kymo_source_data, "kymograms") + "/";
	kymo_dir_image = kymo_dir + title  + "/";
	kymo_dir_image_scaled = kymo_dir_image + "scaled/";
	dirList = newArray(kymo_dir, kymo_dir_image, kymo_dir_image_scaled);
	for (j = 0; j < dirList.length; j++)
		if (!File.exists(dirList[j]))
			File.makeDirectory(dirList[j]);
	roiManager("reset");
	roiManager("Open", roi_dir + title + "-RoiSet.zip");
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
		kymo_path = kymo_dir_image + "ROI_" + j + 1;
		if (!File.exists(kymo_path + ".tif") || overwrite == true)
			saveAs("TIFF", kymo_path);
		rename("kymogram");
		for (k = 0; k < 2; k++) {
			run("Scale...", "x=1.0 y=5 z=1.0 depth=2 interpolation=" + interpolation[k] + " average create");
			kymo_path = kymo_dir_image_scaled + "ROI_" + j + 1 + "-int_" + interpolation[k];
			if (!File.exists(kymo_path) || overwrite == true)
				saveAs("TIFF", kymo_path);
			close();
		}
		close("kymogram");
	}
	close(title);
}

function displayKymograms(k){
	prepare();
	this_img = "> this image <";
	next_img = "-> next image";
	prev_img = "<- previous image";
	kymo_path = kymo_dir_image;
	kymo_list = getFiles(kymo_path);
	kymo_count = kymo_list.length;
	list_plus = Array.concat(this_img, next_img, prev_img, list);
	display_next = this_img;
	excluded_string = findExcluded(kymo_path);
	while (display_next == this_img){
		Dialog.createNonBlocking("Select ROIs for display:");
			Dialog.addMessage("Current image (" + k+1 + "/" + list.length + "): " + list[k]);
			Dialog.addChoice("Display next:", list_plus, this_img);
			Dialog.addString("Kymograms to display:", 1 + "-" + kymo_count);
			Dialog.addChoice("Display", newArray("regular","scaled", "scaled-interpolated"));
			Dialog.addMessage("Currently excluded kymograms:" + excluded_string);
			Dialog.addString("Exclude kymograms:", "");
			Dialog.addString("Restore kymograms:", "");
			Dialog.setLocation(screenWidth*2.07/3, screenHeight*6/9);
			Dialog.show();
			display_next = Dialog.getChoice();
			kymogram_IDs = sortIDs(Dialog.getString());
			display_type = Dialog.getChoice();
			kymograms_to_exclude = sortIDs(Dialog.getString());
			kymograms_to_include = sortIDs(Dialog.getString());
			

		if (display_next != this_img)
			break;
		
		if (kymograms_to_exclude.length > 0)
			excludeKymograms(kymograms_to_exclude, "exclude");
		if (kymograms_to_include.length > 0)
			excludeKymograms(kymograms_to_include, "include");
		excluded_string = findExcluded(kymo_dir_image);
		excluded_array = sortIDs(excluded_string);
		
		kymo_path = kymo_dir_image;
		suffix = ".tif";
		if (display_type == "scaled"){
			kymo_path = kymo_dir_image_scaled;
			suffix = "-int_None" + suffix;
		} else if (display_type == "scaled-interpolated"){
			kymo_path = kymo_dir_image_scaled;
			suffix = "-int_Bilinear" + suffix;
		}
	
		close("ROI*");
		offset_x = screenWidth/3;
		offset_y = screenHeight/9;
		Array.show(excluded_array);
		for (j = 0; j < kymogram_IDs.length; j++){
			kymogram = kymo_path + "ROI_" + kymogram_IDs[j] + suffix;
			if (!contains(excluded_array, kymogram_IDs[j])){
				open(kymogram);
				setLocation(offset_x, offset_y);
				run("View 100%");
				getLocationAndSize(x, y, width, height);
				offset_x += width;
				if (offset_x + width >= screenWidth){
					offset_x = screenWidth/3;
					offset_y += height;
				}
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

function analyzeKymograms(){
	a = "fourier transform for dominant directions";
		return "multicolour image for each kymogram";
	b = "segment into objects";
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
		if (array[i] > kymo_list.length)
			array[i] = kymo_list.length;
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

function findKymograms(dir, count){
	list = getFileList(dir);
	for (i = 0; i < list.length; i++){
		if (endsWith(list[i], "/"))
			count = findKymograms(dir + list[i], count);
		else if (startsWith(list[i], "ROI_"))
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
	for (i = 1; i <= 2; i++){
		Stack.setChannel(i);
		run(LUTs[i-1]);
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
			old_name = kymo_path + "ROI_" + list[i] + ".tif";
			new_name = replace(old_name, ".tif", "-excluded.tif");
		} else if (operation == "include"){
			old_name = kymo_path + "ROI_" + list[i] + "-excluded.tif";
			new_name = replace(old_name, "-excluded", "");
		}
		File.rename(old_name, new_name); 
		close("Log");
	}
}
