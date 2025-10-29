#!/bin/bash


echo "Killing steamapi cluster..."

k3d cluster delete steamapi

echo "Killed."
