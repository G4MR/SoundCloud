import times, nre, os

proc scLogErrors*(errors: seq[string], error_file: string): void =
    
    # Nothing to log
    if isNil(errors) or errors.len < 1:
        return

    # Check if error file exists
    if fileExists(error_file) == false:
        var file_handle : File
        if file_handle.open(error_file, fmReadWrite):
            file_handle.close()
        else:
            echo "Couldn't create error file: " & error_file
            return

    var error_string : string = ""

    # Get timestamp
    let unix_time = getTime()
    let local_time = getLocalTime(unix_time)
    let format_time = format(local_time, "[yyyy/MM/dd - HH:mm:ss]")

    #prepend error string with time stamp
    error_string &= format_time & "\n"

    for error in errors:
        error_string &= error & "\n"

    #strip ending newline from string
    error_string = error_string.replace(re("\n$"), "")

    var file_handle : File
    if file_handle.open(error_file, fmAppend):
        if file_handle.getFileSize() > 0:
            error_string = "\n\n" & error_string
        file_handle.write(error_string)
        file_handle.close()
    else:
        echo "Couldn't save errors to error file: " & error_file
        return