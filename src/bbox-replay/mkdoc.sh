#!/bin/bash

asciidoctor replay_bbox_ltm.adoc
asciidoctor -b docbook replay_bbox_ltm.adoc
fopub.sh replay_bbox_ltm.xml && rm -f replay_bbox_ltm.xml
   
