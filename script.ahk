!c:: ;if Alt+c (!=Alt) is pressed do...
{
	input := strLower(InputBox("", "Enter Command", "w100 h66").Value) ;read input
	Loop read, "commands.txt" ;read commands from "commands.txt" line by line
	{
		line := StrSplit(A_LoopReadLine, ",", "`"") ;split line by comma, ignore "
		if (input == line[1])
		{
			try Run line[2] 
			break
		}
	}
}