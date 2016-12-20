xquery version "1.0-ml";
(:
  Baton semaphore manager code.

  There is a "baton" semaphore used to ensure that across all hosts in the
  cluster, and across all task server kickoffs (e.g. 1x per minute), that
  there is ever only one looping thread running per cluster.

  The "baton" is like a relay race baton.  One looping process is running
  it's leg, and when it gets to the next in line (which happens when the
  next scheduled task is kicked off at e.g. 1 minute), the baton is passed 
  on and the new task takes over the running.  
  Only the process with the baton (which is specific to a domain/target within
  the cluster) checks for and processes requests.
  The threads need to be singled out only for a specific domain/target
  combination, since multiple domains/targets can be processed at once.

  There is a call parameter that can be used to control how and when a
  handoff occurs. If the renew-timestamp flag is specified, then every
  query by a process holding the baton restarts the handoff timeout.
  
  While setting the flag to false forces a baton handoff when the handoff
  timeout has expired, setting the flag to true will cause no handoffs to
  occur as long as the holdng process asks for the baton again within the
  handoff timeout.

  This code manages the handoff of the baton between processes.  There are
  several cases of requests for the baton:

  IF renew-timestamp is false:
    - 1 - A new process asks for the baton, and there is no existing process
      with the baton. (e.g. First process to startup after a reboot.)
      -> Baton is given to the new process to run, process "ID" and time is 
         stored.
    - 2 - A new process asks for the baton, but an existing process is running
          already but has not yet reached the handoff timeout.
      -> Baton is not changed - the new asking process is denied the baton.
    - 3 - A new process asks for the baton, and an existing process is running
          already and has reached the handoff timeout.
      -> Baton is given to the new process to run, process "ID" and time of
         handoff is stored. Additionally, the last baton holder finishes
         the run-out and exits (see scenario 4 for the last holder
         processing)
    - 4 - The last process to hold the baton is running and rechecks whether
          a handoff happened. A handoff did occur since last check.
      -> The process does not perform any more checks, and simply exits 
         gracefully after being denied the baton renewal (run-out after
         baton handoff)
    - 5 - The last process to hold the baton is running and rechecks whether
          a handoff happened. No handoff has happened.
      -> The process is told that it still has the baton, and the process
         continues to run and recheck periodically for handoff.

  IF renew-timestamp is true:
:)


import module namespace warden-common = "http://marklogic.com/xdmp/flexible-replication/warden-common"
    at "/warden/warden-common";


(: A unique URI that specifies which baton to synchronize on. :)
declare variable $baton-uri as xs:string external;

(: The ID of the process requesting the baton :)
declare variable $control-id as xs:string external;

(: Whether to allow the baton holder to renew their use of the baton upon each query :)

