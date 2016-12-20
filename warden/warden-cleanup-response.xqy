xquery version "1.0-ml";
(:
  Gets a directory listing, filters out only the files matching the input
  file mask, and removes those files.  This should be used to cleanup old,
  unprocessed requests after a newer version of the same request has been
  successfully processed.

  There are settings that control how long to leave old files behind.  This
  is used to determine the health of the guard.  If files are left behind 
  for too long, then it signifies that the guard is overloaded or down.

  Note that this cleanup is spawned, since the main processing doesn't care
  whether it completes - and the main processing should not be held up while
  the deletes are being performed.

  Note that unlike the request cleanup (which takes in a set of files),
  the response cleanup determines its own set of files to operate on.  This
  is due to the difference in how requests are processed (no specific
  filename is known) vs how reponses are processed (a specific response
  filename is known).
:)


import module namespace warden-common = "http://marklogic.com/xdmp/flexible-replication/warden-common"
    at "/warden/warden-common.xqy";


declare namespace dir = "http://marklogic.com/xdmp/directory";


(: Mask of while files to consider for delete :)
declare variable $file-mask as xs:string external;

declare variable $path := warden-common:get-config-value( "warden.catch-dir" );


let $_ := xdmp:trace( "warden-cleanup-response", "start:" || $file-mask || " within " || $path )

(: Get file listing :)
let $file-list := xdmp:filesystem-directory( $path )

(: Filter out only those that match the mask :)
let $filtered := $file-list/dir:entry[ fn:matches( ./dir:filename/fn:string(), $file-mask ) ]

let $_ := 
    for $file in $filtered
      let $filename := $file/dir:pathname/fn:string()
      return
      (
        xdmp:trace( "warden-cleanup-response", "cleaning old file " || $filename ),
        xdmp:filesystem-file-delete( $filename )
      )

let $_ := xdmp:trace( "warden-cleanup-response", "done: " || $file-mask )

return()
