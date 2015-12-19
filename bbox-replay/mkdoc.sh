#!/bin/bash

asciidoctor replay_bbox_ltm.adoc
asciidoctor -b docbook replay_bbox_ltm.adoc
/opt/src/asciidoctor-fopub/fopub replay_bbox_ltm.xml 
   
