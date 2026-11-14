# Eddy, 2026-11-14 ("Bible needs a proper Swift grill ... Do the things we have settled"):
# a lane named in agent-config/master/parked-lanes opens nothing: not its batch head, not a
# single record of its track, not a resumed build of it. $p is the list of parked names.
(if ((.batch.lane // "") as $l | ($p | index($l)) != null) then del(.batch) else . end)
| .next |= ((. // []) | map(select(((.track // "") as $t | (.lane // "") as $l | ($p | index($t)) == null and ($p | index($l)) == null))))
| .resume |= ((. // []) | map(select(((.track // "") as $t | ($p | index($t)) == null))))
