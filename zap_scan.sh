#!/bin/bash
docker run --network host -v $(pwd):/zap/wrk owasp/zap2docker-stable zap-baseline.py -t http://localhost:8090 -r zap_report.html
