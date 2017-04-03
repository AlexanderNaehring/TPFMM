#!/bin/bash

xdg-desktop-menu install tpfmm.desktop --novendor
xdg-mime default tpfmm.desktop x-scheme-handler/tpfmm
