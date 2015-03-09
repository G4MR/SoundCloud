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

import httpclient, os, strutils, net, uri, cgi, json, htmlparser
import nre, optional_t
import sctypes

# get content
proc getUrl*(url: string, content: var string, errors: var seq[string]): bool =
    try:
        content = getContent(url)
    except HttpRequestError:
        errors.add("Failed to load url: Error0001 " & url)
        return false
    return true

proc getUrlContents(url: string): string =

    var content : string
    
    try:
        content = getContent(url)
    except HttpRequestError:
        discard

    return content

proc soundcloud_dl*(sc_obj: SoundCloudUrl, save_path: string, overwrite_files: bool, errors: var seq[string]): void =
    
    #setup defaults
    var song_title : string = ""
    var song_author : string = ""
    var soundcloud_url : string = ""
    let soundcloud_base_url : string = "https://soundcloud.com/"

    # check if we're dealing with a soundcloud url
    if sc_obj.url.match(re"^http(s)?://?"):
        soundcloud_url = sc_obj.url
        if soundcloud_url.match(re"^http(s)?://soundcloud\.com/"):
            discard
        else:
            errors.add("Invalid Url " & soundcloud_url)
            return
    else:
        soundcloud_url = soundcloud_base_url & sc_obj.url

    # clean up url then check if we have a proper url
    soundcloud_url = soundcloud_url.replace(re(r"^(?:http(s)?://)", "i"), "")
    soundcloud_url = soundcloud_url.replace(re(r"/$", "i"), "")
    soundcloud_url = soundcloud_url.replace(re(r"/+", "i"), "/")

    # check if valid soundcloud song path
    let sc_parts = soundcloud_url.split("/")
    if sc_parts.len < 3:
        errors.add("Invalid soundcloud song path: Error0000 " & soundcloud_url)
        return

    # recreate soundcloud path
    soundcloud_url = "https://" & soundcloud_url & "/"

    # download page content
    var soundcloud_html : string

    # get html content
    soundcloud_html = getUrlContents(soundcloud_url)
    
    # check content length
    if isNil(soundcloud_html):
        errors.add("Couldn't load data: Error0002 " & soundcloud_url)
        return
    
    # song title
    if sc_obj.custom_title == false:
        var title_meta : seq[string] = @[]
        for match in soundcloud_html.findIter(re("<meta property=\"og:title\" content=\"([^\"]+)\">")):
            title_meta.add(match.captures[0])

        if title_meta.len == 1:
            song_title = strip(title_meta[0]) 
            song_title = song_title.entToUtf8()
        else:
            song_title = sc_parts[2] #default path from url
            song_title = song_title.replace(re(r"\W"), "")
    else:
        song_title = strip(sc_obj.title)
        song_title = song_title.entToUtf8()

    #remove unicode & stuff
    song_title = song_title.replace(re(r"\p{Lm}|\p{Lo}|\p{M}|\p{Cc}"), "")      # ~Most unicode characters, um - foreign characters may not work?
    song_title = song_title.replace(re(r"\s+"), " ")                            # multiple spaces that follow each other 
    song_title = song_title.replace(re(r"(\&[^\;]+\;)"), "")                    # missed entities
    song_title = song_title.replace(re(r"\.+$"), "")                            # titles ending with periods

    let download_file_path = save_path & song_title & ".mp3"

    if overwrite_files == false and fileExists(download_file_path):
        echo "[Overwrite Disabled] Skipped: " & song_title
        return

    # grab soundcloud username
    if sc_obj.skip == false:
        var author_rel : seq[string] = @[]
        for match in soundcloud_html.findIter(re("<link rel=\"author\" href=\"/([^\"]+)\">")):
            author_rel.add(match.captures[0])

        if author_rel.len == 1:
            song_title = song_title & " - " & strip(author_rel[0])

    #loop through matches
    var embed_url_meta: seq[string] = @[]
    for match in soundcloud_html.findIter(re("<meta itemprop=\"embedUrl\" content=\"([^\"]+)\" />", "im")):
        embed_url_meta.add(match.captures[0])

    if embed_url_meta.len < 1:
        errors.add("Couldn't find data: Error0003 " & soundcloud_url)
        return

    # set defaults
    let embed_url = embed_url_meta[0]
    let embed_url_decode = cgi.decodeUrl(embed_url)
    let track_id = embed_url_decode.replace(re(r".*tracks/(\d+).*", "i"), "$1")

    # get js file
    var soundcloud_track_html : string
    if getUrl(embed_url, soundcloud_track_html, errors) == false:
        return

    if soundcloud_track_html.len <= 0:
        errors.add("Couldn't load data: Error0004 " & soundcloud_url)
        return

    var track_matches: seq[string] = @[]
    for match in soundcloud_track_html.findIter(re("<script src=\"(/player/assets/widget.*js)\">", "im")):
        track_matches.add(match.captures[0])

    if track_matches.len < 1:
        errors.add("Couldn't find data: Error0005 " & soundcloud_url)
        return

    let widget_url = "https://w.soundcloud.com" & track_matches[0]

    var soundcloud_widget_js : string
    if getUrl(widget_url, soundcloud_widget_js, errors) == false:
        return

    if soundcloud_widget_js.len < 1:
        errors.add("Couldn't load data: Error0006 " & soundcloud_url)
        return

    # lets split the data into parts because it's too big to search
    # then get the client_id
    let sc_part = soundcloud_widget_js.split(re("production:"), 2)
    if sc_part.len != 2:
        errors.add("Invalid part data: Error0007 " & soundcloud_url)
        return

    let sc_part2 = sc_part[1].split(re("},visual"), 2)

    if sc_part2.len != 2:
        errors.add("Invalid part data: Error0008 " & soundcloud_url)
        return

    # get client id 
    var client_id : string = sc_part2[0].replace(re("^\"|\"$", "im"), "")

    # json path to mp3
    let api_json_url = "https://api.soundcloud.com/i1/tracks/" & track_id & "/streams?client_id=" & client_id & "&format=json"
    
    var api_json_data : string 
    if getUrl(api_json_url, api_json_data, errors) == false:
        return

    if api_json_data.len < 1:
        errors.add("Couldn't load data: Error0009 " & soundcloud_url)
        return

    let api_json = parseJson(api_json_data)
    let mp3_file : string = api_json["http_mp3_128_url"].str

    # remove old file
    if overwrite_files == true and fileExists(download_file_path):
        removeFile(download_file_path)

    try:
        downloadFile(mp3_file, download_file_path)
    except IOError:
        errors.add("Error saving file " & soundcloud_url)
        return
    except HttpRequestError:
        errors.add("Couldn't retrieve song " & soundcloud_url)
        return
    except TimeoutError:
        errors.add("Connection timed out " & soundcloud_url)
        return
    except:
        errors.add("Some unknown issue " & soundcloud_url)
        return
    finally:
        discard

    echo (song_title & ".mp3 was complete")