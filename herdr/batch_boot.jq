# Master plan 1d (M3, BS-IOS-TASK-1709): the record heading the work graph's `.batch`
# boots the batch's own verb — `/build batch <lane>`, or `/spec batch <lane>` while the
# batch has Spec Needed members — instead of `/build <ID>`. A lone record keeps
# `/build <ID>`. Shared by goals.sh and goal_done.sh so both fills dispatch alike.
# Batch first (orders 2026-11-12): the head goes to the front of `.next`, even when the
# graph ranked it lower or left it out, and the other members leave `.next`: the batch
# tab builds them, so none opens as a single build beside it.
(.batch // null) as $b
| if $b != null and (($b.ids // []) | length) > 0 and (($b.verb // "") | test("^/(build|spec) batch "))
  then .next |= ((. // []) as $n
    | ([$n[] | select(.id == $b.ids[0])][0] // {id: $b.ids[0], title: ""}) as $head
    | [$head + {boot: $b.verb, lane: $b.lane}] + [$n[] | select(.id as $i | ($b.ids | index($i)) | not)])
  else . end
