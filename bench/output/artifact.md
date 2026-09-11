Benchmark

Envelope and round-trip cost over a 100-entry artifact, which the build
pays once per file written and the cache pays once per file on every
reload.


## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M5 Pro</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">18</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">48 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.18.4</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">27.3.4.15</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">5 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">1</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">2 s</td>
  </tr>
</table>

## Statistics



Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Deviation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.envelope/1</td>
    <td style="white-space: nowrap; text-align: right">952133.58</td>
    <td style="white-space: nowrap; text-align: right">0.00105 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1224.91%</td>
    <td style="white-space: nowrap; text-align: right">0.00067 ms</td>
    <td style="white-space: nowrap; text-align: right">0.00158 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.read/1</td>
    <td style="white-space: nowrap; text-align: right">193.16</td>
    <td style="white-space: nowrap; text-align: right">5.18 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.53%</td>
    <td style="white-space: nowrap; text-align: right">5.16 ms</td>
    <td style="white-space: nowrap; text-align: right">5.55 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.write/2</td>
    <td style="white-space: nowrap; text-align: right">30.87</td>
    <td style="white-space: nowrap; text-align: right">32.40 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.90%</td>
    <td style="white-space: nowrap; text-align: right">32.37 ms</td>
    <td style="white-space: nowrap; text-align: right">35.46 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Artifact.envelope/1</td>
    <td style="white-space: nowrap;text-align: right">952133.58</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.read/1</td>
    <td style="white-space: nowrap; text-align: right">193.16</td>
    <td style="white-space: nowrap; text-align: right">4929.37x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.write/2</td>
    <td style="white-space: nowrap; text-align: right">30.87</td>
    <td style="white-space: nowrap; text-align: right">30845.34x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">Artifact.envelope/1</td>
    <td style="white-space: nowrap">0.00153 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Artifact.read/1</td>
    <td style="white-space: nowrap">7.30 MB</td>
    <td>4780.6x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Artifact.write/2</td>
    <td style="white-space: nowrap">33.84 MB</td>
    <td>22168.51x</td>
  </tr>
</table>