process_choices = newArray("Define ROIs", "Check ROIs", "Create kymograms", "Check kymograms", "Analyze kymograms", "exit");
path = getDirectory("current");
eval("script", File.openAsString(path + "functions.ijm"));


function dialog_window(){
	help_message = "<html>"
		+"<b>Directory</b><br>"
		+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
		+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. All folders with names <u>ending</u> with the word \"<i>data</i>\" are processed."
		+"All other folders are ignored.<br>"
		+"<br>"
		+"<b>Subset</b> <i>(optional)</i><br>"
		+"If used, only images with filenames containing the specified <i>string</i> (i.e., group of characters and/or numbers) will be processed. "
		+"This option can be used to selectively process images of a specific strain, condition, etc. "
		+"Leave empty to process all images in specified directory (and its subdirectories).<br>"
		+"<br>";
//	Dialog.create("Whatcha doin'?");
	Dialog.createNonBlocking("Kymolyzer");
		Dialog.addChoice("Select an operation:", process_choices);
		Dialog.addHelp(help_message);
		Dialog.show();
		process = Dialog.getChoice();
	
	if (matches(process, process_choices[0]))
		define_ROIs();
	else if (matches(process, process_choices[1]))
		check_ROIs();
	else if (matches(process, process_choices[2]))
		create_kymograms();
	else if (matches(process, process_choices[3]))
		check_kymograms();
	else if (matches(process, process_choices[4]))
		analyze_kymograms();
	else
		exit("See ya");
	dialog_window();
}

function define_ROIs(){
	run("Grays");
	run("Enhance Contrast...", "saturated=0.35");
//	run("Macro...", "path=/Kymolyzer/functions.ijm");
	hello();
}

function check_ROIs(){
	run("Flip Horizontally", "stack");
}

function create_kymograms(){
	run("Gaussian Blur...", "sigma=1 stack");
}

function check_kymograms(){
	run("Sharpen", "stack");
}

function analyze_kymograms(){
	run("Sharpen", "stack");
}

dialog_window();