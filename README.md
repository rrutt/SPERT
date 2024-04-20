# Stochastic Project Evaluation & Review Technique

_Version 1.0.0+20240420  ([Version Release Notes](#ReleaseNotes))_ 

The _Stochastic Project Evaluation & Review Technique_ program, **SPERT**, supports Critical Path Method project planning, including generation of text-based GANTT charts.

This program is free open source software licensed under the [MIT License](./MIT-License.html), Copyright © 2024 Rick Rutt.

Information about the source code compilation of the **SPERT** program appear at the end of this document in the [Developer Information](#DeveloperInformation) section.

## About the Software

The software is a self-contained executable program, written in **[Free Pascal](https://www.freepascal.org/)**, that runs on Microsoft Windows or Ubuntu Linux (and presumably other Linux distributions).
(No separate run-time environment is required to run the program.)

The **[Lazarus Integrated Development Environment](https://www.lazarus-ide.org/)** was used to develop the program.
(Both Free Pascal and the Lazarus IDE are free open-source software products.)

## Downloading and Running the Program

### Microsoft Windows

You can run the **SPERT** program on Microsoft Windows as follows:

- Download the **SPERT.exe** binary executable file from the **bin** sub-folder from this GitHub.com page.

- To uninstall the program, simply delete the **PascalBoids.exe** file.

### Ubuntu Linux

You can run the **SPERT** program on Ubuntu Linux (and presumably other Linux distributions) as follows:

- Download the **SPERT** binary executable file (with no file extension) from the **bin** sub-folder from this GitHub.com page.

- Ensure the **SPERT** file has the executable permission.  From a Files window, right-click the file, select Properties, and use the Permissions tab to enable the Execute permission.  To do this in a Terminal window, use the following command:
  
    chmod +x SPERT

- To uninstall the program, simply delete the **PascalBoids** binary executable file.

**_Note_**: When running on Linux, the StdErr error messages may not appear in the terminal.
Instead these messages may be written to a file named **CON** in the current directory.

### Running the Program

Open a Command Prompt or Terminal window.

Type the **SPERT.exe** (on Windows) or **SPERT** (on Linux) file name (with full path if necessary) with no additional arguments to view usage information for the program.

#### Command Line Arguments
	
	filename  input file name
	/PN       Print input Network
	/PD       Print Detailed analysis results by task
	/PG       Print Gantt chart
	/PR       Print Resource usage histogram and total
	/PF       Print distributions of milestone Finish times
	/NSn      Number of Simulations is "n" (default is l)
	/RLn      Resource Limit is "n" (default is infinity)
	/SDmmdd   Start Date month and day (for time scale headings)
	          (Leading zeros are required for "mm" and "dd")
	
The standard output may be redirected with >FILENAME

#### Input File Format
	
The input file is read in the following format (any blank lines are ignored):
	
	Project Name on one line
	TaskCode Optimistic MostLikely Pessimistic [@ResCount] [Task Desc]
	...
	*
	PredTaskCode SuccTaskCode
	...
	*
	
- **TaskCode** is a short taskname (up to 10 chars.) without blanks.
If **TaskCode** begins with a **#***, then it is a _Milestone_ task.
Preceding **TaskCode** or **#TaskCode** with **^** implies that this task is a _successor_ to the task above it.
If **TaskCode** ends with a **!**, the task is a _High Priority_ Task.

- **Optimistic**, **MostLikely**, and **Pessimistic** are task time span estimates.

- **ResCount** is an optional real _Resource_ count. (1.0 is assumed if omitted).

- **Task Desc** is an optional longer description and allows blanks.

- **PredTaskCode** and **SuccTaskCode** form a _precedence_ pair of two tasks.
(The **#** for _Milestones_ and **!** for _Priority Tasks_ are optional for these task codes.)
A ditto (**"**) for either **PredTaskCode** or **SuccTaskCode**
indicates reuse of the value from the preceding line.

- (The last * line is optional.)

The file **test\SPERT-Example.txt** contains a small sample project for use in testing the **SPERT** program:
	
	Example Project Schedule
	
	kickoff    1 1 1 @3 All-day Kickoff Meeting (entire team)
	^interview 3 5 10 @3 Requirements Interviews (entire team)
	r-fin      1 2.5 5 Financial Subsystem Requirements Doc.
	r-mfg      2 4 10 Manufacturing Subsystem Requirements Doc.
	r-sls      0.5 1.5 5 Sales Subsystem Requiremetns Doc.
	#wt-r      0.5 0.5 1 @3 Requirements Doc. Walk-thru (entire team)
	
	d-fin  3 6 12 Design Financial Subsystem
	^p-fin 8 12 25 Program & Test Financial Subsystem
	
	d-mfg  4 10 20 Design Manufacturing Subsystem
	^p-mfg 10 15 30 Program & Test Manufacturing Subsystem
	
	d-sls  3 6 10 Design Sales Subsystem
	^p-sls 8 10 20 Program & Test Sales Subsystem
	
	test!    5 10 20 @2 Integration Test/Debug Entire System
	userdoc 10 12 15 Write User Documentation
	
	#install 1 2 5 Install System
	
	*
	
	interview r-fin
	"         r-mfg
	"         r-sls
	
	r-fin wt-r
	r-mfg "
	r-sls "
	
	wt-r d-fin
	"    d-mfg
	"    d-sls
	
	d-fin userdoc
	d-mfg "
	d-sls "
	
	p-fin test
	p-mfg "
	p-sls "
	
	test    install
	userdoc "
	
	*


#### Gantt Chart
	
In the output Gantt chart, the following symbols are used:
	
	X = One day in task on the Critical Path
	9 = One day in task that was critical in 90% of simulations
	...
	1 = One day in task that was critical in 10% of simulations
	+ = One day in non-critical task
	- = trailing float (resource limits ignored)
	. = leading delay (only occurs if resources are limited)

Here is an example Gantt chart:
	
	Example Project Schedule
	
	Results from Mean Durations
	
	           422! 429! 5 6! 513! 520! 527! 6 3! 610! 617! 624! 7 1! 7 8!
	          ....+....1....+....2....+....3....+....4....+....5....+....6....+....7
	
	kickoff   X
	interview  XXXXXX
	r-fin            +++--
	r-mfg            XXXXXX
	r-sls            +++---
	#wt-r                 X
	d-fin                  +++++++-------
	p-fin                         +++++++++++++++-------
	d-mfg                  XXXXXXXXXXXX
	p-mfg                             XXXXXXXXXXXXXXXXXXX
	d-sls                  +++++++----------
	p-sls                        +++++++++++++----------
	test!                                                XXXXXXXXXXXX
	userdoc                           +++++++++++++-----------------
	#install                                                        XXX

Here is an example Gantt chart after 100 Monte-Carlo simulations:
	
	Example Project Schedule
	
	Expected Results from 100 Monte-Carlo Simulations
	
	           422! 429! 5 6! 513! 520! 527! 6 3! 610! 617! 624! 7 1! 7 8!
	          ....+....1....+....2....+....3....+....4....+....5....+....6....+....7
	
	kickoff   X
	interview  XXXXXXX
	r-fin            222--
	r-mfg            999999
	r-sls            111--
	#wt-r                 X
	d-fin                  2222222--------
	p-fin                         2222222222222222--------
	d-mfg                  999999999999
	p-mfg                             9999999999999999999
	d-sls                  +++++++-----------
	p-sls                        ++++++++++++++-----------
	test!                                                XXXXXXXXXXXXX
	userdoc                            ++++++++++++------------------
	#install                                                          XXX
	
Here is an example Gantt chart using 100 simulations but with the Resource Limit set to 3 (**/RL3**):
	
	Example Project Schedule
	
	Expected Results from 100 Monte-Carlo Simulations
	Resource Limit is 3
	
	           422! 429! 5 6! 513! 520! 527! 6 3! 610! 617! 624! 7 1! 7 8!
	          ....+....1....+....2....+....3....+....4....+....5....+....6....+....7
	
	kickoff   +
	interview  ++++++
	r-fin            +++
	r-mfg            ++++++
	r-sls            +++
	#wt-r                 ++
	d-fin                  ++++++++
	p-fin                         +++++++++++++++
	d-mfg                  ++++++++++++
	p-mfg                              ++++++++++++++++++
	d-sls                  +++++++
	p-sls                        +++++++++++++
	test!                                                2222222222222
	userdoc                            ......++++++++++++
	#install                                                         XXX

#### Resource Usage Chart
	
In the resource usage chart, the following symbols are used:
	
	X = One unit of resource fully used that day
	9 = 0.9 units of resource
	...
	1 = 0.1 units of resource

Here is an example Resource Usage chart: 

	Example Project Schedule
	
	Results from Mean Durations
	
	
	Expected Resource Use
	
	           422! 429! 5 6! 513! 520! 527! 6 3! 610! 617! 624! 7 1! 7 8!
	          ....+....1....+....2....+....3....+....4....+....5....+....6....+....7
	                                                                    
	                                                                    
	                                  7XXXXXXX                          
	          XXXXXXXXX2  4XXXXXXXXXXXXXXXXXXXXXX                       
	          XXXXXXXXXX  XXXXXXXXXXXXXXXXXXXXXXXX7     4XXXXXXXXXXX4   
	          XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX 
	
	Expected Total Resource Use =   142.5

Here is an example Resource Usage chart after 100 Monte-Carlo simulations:
	
	Example Project Schedule
	
	Expected Results from 100 Monte-Carlo Simulations
	
	
	Expected Resource Use
	
	           422! 429! 5 6! 513! 520! 527! 6 3! 610! 617! 624! 7 1! 7 8!
	          ....+....1....+....2....+....3....+....4....+....5....+....6....+....7
	                                                                                       
	                                                                                       
	                             12234566676531                                            
	          XXXXXXX852 13589XXXXXXXXXXXXXXXXX852                                         
	          XXXXXXXXXX9XXXXXXXXXXXXXXXXXXXXXXXXXX9987666666666655432                     
	          XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX87654433221111111  
	
	Expected Total Resource Use =   143.2
	
	Maximum Resource Use
	
	           422! 429! 5 6! 513! 520! 527! 6 3! 610! 617! 624! 7 1! 7 8!
	          ....+....1....+....2....+....3....+....4....+....5....+....6....+....7
	                                                                                       
	                                                                                       
	                             XXXXXXXXXXXXXXXXXXXXX5                                    
	          XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX9X1                              
	          XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX2  
	          XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX3
	
	 Lowest Total Resource Use =   117.8
	 Highest Total Resource Use =   175.4

#### Milestone Finish Distributions
	
	In the finish distributions, an asterisk marks the "mean" value.

Here is an example Finish Distributions chart after 100 Monte-Carlo simulations:

	Example Project Schedule
	
	Expected Results from 100 Monte-Carlo Simulations
	
	Distributions of Milestone Task Finish Times
	
	#wt-r      Requirements Doc. Walk-thru (entire team)
	
	    9 XXXX
	   10 XXXXXXX
	   11 XXXXXXXXXXXXXX
	   12 XXXXXXXXXXXXXXX
	   13*XXXXXXXXXXXXXXX
	   14 XXXXXXXXXX
	   15 XXXXXXXXXXXXXX
	   16 XXXXXXXX
	   17 XXXXXXXXXX
	   18 X
	   19 X
	   20 X
	
	#install   Install System
	
	   47 X
	   48 XX
	   49 X
	   50 XXX
	   51 XXXXXX
	   52 XXX
	   53 XXXX
	   54 XXXXX
	   55 XXXX
	   56 XXXXXXXXXX
	   57 XXXXXXXXX
	   58 XXXX
	   59*XXXXX
	   60 XXXXXXXX
	   61 XX
	   62 XX
	   63 XXXXXXXX
	   64 XX
	   65 XXXXXX
	   66 XXX
	   67 XXX
	   68 XX
	   69 XXX
	   70 XX
	   71 X
	   72 X

## The Triangular Probability Distribution

The Triangular probability distribution provides an alternative to a Gaussian normal distribution when specific lower and upper limits are desired on the resulting value. The triangular distribution can also be skewed to yield an asymmetrical distribution.

The triangular distribution is also mathematically tractable; its mode, median, expected value (mean), and inverse can be derived and computed.

For further information, see the **[Wikipedia article](https://en.wikipedia.org/wiki/Triangular_distribution)**.

<a name="DeveloperInformation"></a>
## Developer Information

### Source code compilation notes

The integrated development environment for Free Pascal is the **[Lazarus IDE for Free Pascal](https://www.lazarus-ide.org/)**.

Download the **Lazarus IDE**, including **Free Pascal**, from  here:

- **<https://www.lazarus-ide.org/index.php?page=downloads>**

After installing the **Lazarus IDE**, clone this GitHub repository to your local disk.
Then double-click on the **src\SPERT.lpr** project file to open it in **Lazarus**. 

_**Note:**_ Using the debugger in the **Lazarus IDE** on Windows 10 _**might**_ require the following configuration adjustment:

- **[Lazarus - Windows - Debugger crashing on OpenDialog](https://www.tweaking4all.com/forum/delphi-lazarus-free-pascal/lazarus-windows-debugger-crashing-on-opendialog/)**

When **Lazarus** includes debugging information the executable file is relatively large.
When ready to create a release executable, the file size can be significantly reduced by selecting the menu item **Project | Project Options ...** and navigating to the **Compile Options | Debugging** tab in the resulting dialog window.
Clear the check-mark from the **Generate info for the debugger** option and then click the **OK** button.
Then rebuild the executable using the **Run | Build** menu item (or using the shortcut key-stroke _**Shift-F9**_).

<a name="ReleaseNotes"></a>
## Release Notes

### Version 1.0.0

Initial Free Pascal release.
