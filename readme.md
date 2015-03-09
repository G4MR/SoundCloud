My first finished Nim-Lang Project.  Basically it allows you to enter a 
soundcloud url and then download the mp3 from the website.  

Building
-------------
```
nim c -d:ssl -d:release soundcloud.nim
```

Settings.json
-------------

**save_path** - is used as a direct path to where you want your mp3 files to be saved.

**errors_file** - this is the file that you want to store your errors to, generic errors atm

**overwrite_files** - this makes it so you can skip over files you already have on your computer

**song\_list\_path** - this is the file in which you store your link files

All settings not set will be set automatically (hard coded, if not found)

Songs.txt
---------------

Currently there are two options when adding links to the songs file for downloading. First
you have a basic single song file line like so:

```
http://soundcloud.com/user/song-page
```

This will attempt to create the song title for you based on their title and use the users
account name as the author.  This can be useful for accounts that have official artists names
or you can do the following to ignore the author name:

```
skip | http://soundcloud.com/user/song-page
```

This skips the account author name from being appended to the song file.

Last, we can create our own song titles for urls.  Useful for random music or podcasts with
incorrect titles.

```
Song Title | http://soundcloud/user/song-page
```

_(This is for learning purposes only)_