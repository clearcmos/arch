#!/bin/bash
echo "Flushing DNS cache..."
resolvectl flush-caches
echo "DNS cache flushed."
