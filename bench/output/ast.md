Benchmark

Markdown parsing runs once per document and is the hottest path in a
build: every module doc, guide, and notebook goes through it. Inputs span
a terse module doc to a long guide.


## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M4 Max</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">16</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">128 GB</td>
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



__Input: large (50 sections)__

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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap; text-align: right">66.86</td>
    <td style="white-space: nowrap; text-align: right">14.96 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.36%</td>
    <td style="white-space: nowrap; text-align: right">14.95 ms</td>
    <td style="white-space: nowrap; text-align: right">15.61 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap;text-align: right">66.86</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap">16.26 MB</td>
    <td>&nbsp;</td>
  </tr>
</table>



__Input: medium (10 sections)__

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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap; text-align: right">333.78</td>
    <td style="white-space: nowrap; text-align: right">3.00 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.13%</td>
    <td style="white-space: nowrap; text-align: right">2.98 ms</td>
    <td style="white-space: nowrap; text-align: right">3.21 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap;text-align: right">333.78</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap">3.11 MB</td>
    <td>&nbsp;</td>
  </tr>
</table>



__Input: small (1 section)__

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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap; text-align: right">3.28 K</td>
    <td style="white-space: nowrap; text-align: right">305.16 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.67%</td>
    <td style="white-space: nowrap; text-align: right">302.50 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">360.60 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap;text-align: right">3.28 K</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap">324.18 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>