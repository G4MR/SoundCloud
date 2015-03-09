discard """
The MIT License (MIT)

Copyright (c) <2015> <Lamonte H.>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

import os, json, strutils, nre, optional_t
import sctypes, source, sc_errors

echo "Download starting...\n\n"

var 
    errors: seq[string] = @[]
    json_data: string
    parsed_json : JsonNode
    settings_data: string = ""

let settings_file = "settings.json"

# Check if File Exists
if fileExists(settings_file):

    # Try getting content
    settings_data = readFile(settings_file)

    # Try parsing json
    try:
        parsed_json = parseJson(settings_data)
    except JsonParsingError:
        quit("Couldn't parse settings.json")
    except:
        echo "Creating defaults: save_path (string), song_list_path (string), overwrite_files (bool)"

# Get settings
var 
    save_path : string = "mp3s/"
    errors_file: string = "log_errors.txt"
    song_list_path : string = "songs.txt"
    overwrite_files : bool = true

if parsed_json != nil:
    if parsed_json.hasKey("save_path"):
        save_path = parsed_json["save_path"].str

    if parsed_json.hasKey("errors_file"):
        errors_file = parsed_json["errors_file"].str

    if parsed_json.hasKey("song_list_path"):
        song_list_path = parsed_json["song_list_path"].str

    if parsed_json.hasKey("overwrite_files"):
        overwrite_files = parsed_json["overwrite_files"].bval

# clean up save path
save_path = save_path.replace(re(r"/$", "i"), "") & "/" # readd trailing slash
save_path = save_path.replace(re(r"/+", "i"), "/") 

# Get song urls
var save_data : string
var song_urls: seq[SoundCloudUrl] = @[]

if fileExists(song_list_path):
    save_data = readFile(song_list_path)

    # split a non empty url
    if save_data.len > 0:
        for line in splitLines(save_data):

            # split lines into parts
            var line_parts = line.split("|")
            
            # just a url
            case line_parts.len
            of 1: song_urls.add(SoundCloudUrl(url: strip(line_parts[0]), skip: false, custom_title: false))
            of 2:
                let song_url = strip(line_parts[1])
                var title_or_skip = strip(line_parts[0])
                if title_or_skip.match(re("^skip$", "im")):
                    song_urls.add(SoundCloudUrl(url: song_url, skip: true, custom_title: false))
                else:
                    song_urls.add(SoundCloudUrl(url: song_url, skip: true, title: title_or_skip, custom_title: true))
            else: discard

# check if we're grabbing from the cmd line
if declared(paramCount) and paramCount() >= 1:
    
    #reset song urls sequence
    song_urls = @[]

    case paramCount()
    of 1:
        let song_url = strip(paramStr(1))
        song_urls.add(SoundCloudUrl(url: song_url, skip: false, custom_title: false))
    of 2:
        let song_url = strip(paramStr(2))
        let title_or_skip = strip(paramStr(1))

        if title_or_skip.match(re("^skip$", "im")):
            song_urls.add(SoundCloudUrl(url: song_url, skip: true, custom_title: false))
        else:
            song_urls.add(SoundCloudUrl(url: song_url, skip: true, title: title_or_skip, custom_title: true))
    else: discard

for song_url in song_urls:
    soundcloud_dl(song_url, save_path, overwrite_files, errors)

if errors.len > 0:
    echo "\n- Log file has been written\n"
    scLogErrors(errors, errors_file)
else:
    echo "\n\nDownloads complete\n\n"

echo "Press enter to exit..."

# lazy exit/wait (not sure if nim has a pause function)
let exit = readLine(stdin)