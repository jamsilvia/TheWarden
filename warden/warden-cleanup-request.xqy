xquery version "1.0-ml";
(:
  Loops through the given files and deletes them as a spawned task.

  Note that cleanup is spawned, since the main processing doesn't care
  whether it completes - and the main processing should not be held up while
  the deletes are being performed.
:)


declare namespace dir = "http://marklogic.com/xdmp/directory";


(: List of files to remove.  :)
declare variable $file-list as xs:string+ external;


(
  xdmp:trace( "warden-cleanup-request", "start" ),
  for $filename in $file-list
    return
    (
      xdmp:trace( "warden-cleanup-request", "cleaning old file " || $filename ),
      xdmp:filesystem-file-delete( $filename )
    ),
  xdmp:trace( "warden-cleanup-request", "done" )
)
