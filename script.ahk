!c:: ;if Alt+c (!=Alt) is pressed do...
{
	Switch strLower(InputBox("", "Enter Command", "w100 h66").Value) ;read input
	{
		Case "command1": try Run "path1"
        Case "command2": try Run "path2"
	}
}