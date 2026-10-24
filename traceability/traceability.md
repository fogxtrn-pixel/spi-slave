# SPI Slave Traceability Record

## Design
- Design name: h04_spi_slave
- Protocol: SPI Mode 0
- RTL source: src/h04_spi_slave.sv
- Configuration: config.json
- Pin configuration: pin_order.cfg

## Implementation
- Flow: OpenLane
- PDK: Sky130A
- Run ID: RUN_2026.10.24_15.21.16

## Physical Design Outputs
- Final GDSII: results/gds/h04_spi_slave.gds
- Signoff GDSII: results/gds/h04_spi_slave_signoff.gds

## Reports
- Metrics: results/reports/metrics.csv
- DRC: results/reports/drc.rpt
- LVS: results/reports/39-h04_spi_slave.lvs.rpt

## Verification Status
Refer to the included DRC, LVS, metrics and simulation reports
to determine the actual verification results.

## Reproducibility
The original OpenLane run directory is:
runs/RUN_2026.10.24_15.21.16
