version = "0.1.0";

process_choices = newArray("Define ROIs", "Check ROIs", "Create kymograms", "Check kymograms", "Analyze kymograms", "EXIT");
path = getDirectory("current");
publication = "Zahumensky & Malinsky, 2004; doi: 10.1093/biomethods/bpae075"
GitHub_microscopy_analysis = "https://github.com/jakubzahumensky/microscopy_analysis"
GitHub_kymolyzer = "https://github.com/jakubzahumensky/kymolyzer"

function dialog_window(folder){
	help_message = "<html>"
		+"<center><b>Kymolyzer, version "+ version + "</b></center>"
		+"<center><i>source:" + GitHub_kymolyzer + "</i></center>"
		+"<br>"
		+"<b>Define ROIs & Check ROIs</b><br>"
		+"User is referred to the <i>ROI_prep</i> macros published previously (1, 2).<br>"
		+"<br>"
		+"<b>Create kymograms</b><br>"
		+"Press to create kymograms from defined ROIs. Error is displayed if no ROIs are defined.<br>"
		+"<br>"
		+"<b>Check kymograms</b><br>"
		+"Images in the folder are displayed one-by-one, together with kymograms for each cell (defined ROI). <br>"
		+"<br>"
		+"<b>Analyze kymograms</b><br>"
		+"Kymograms are quantified. Results are saved in a csv file that can be further processed using <i>R scripts</i> published previously (1, 2).<br>"
		+"<br>"
		+"<b>References:</b><br>"
		+"(1) " + publication + "<br>"
		+"(2) " + GitHub_microscopy_analysis + "<br>"
		;
	Dialog.createNonBlocking("Kymolyzer");
		Dialog.addDirectory("Directory:", folder);
		Dialog.addChoice("Select an operation:", process_choices);
		Dialog.addHelp(help_message);
		Dialog.show();
		dir = replace(Dialog.getString(), "\\", "/");
		process = Dialog.getChoice();
	
	message_for_check = "Please use the 'ROI_prep' macro and select: \n"
			+ "- 'Convert Masks to ROIs' if you have segmentation masks \n";
	message_for_define = message_for_check + "- 'Check and adjust ROIs' if you want to create them manually";
	
	if (matches(process, process_choices[0]))
		waitForUser(message_for_define);
	else if (matches(process, process_choices[1]))
		waitForUser(message_for_check);
	else if (matches(process, process_choices[2]))
		create_kymograms();
	else if (matches(process, process_choices[3]))
		check_kymograms();
	else if (matches(process, process_choices[4]))
		analyze_kymograms();
	else
		exit("See ya.");
	dialog_window(dir);
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

initial_folder = ""
dialog_window(initial_folder);