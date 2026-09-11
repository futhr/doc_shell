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
    <td style="white-space: nowrap; text-align: right">74.51</td>
    <td style="white-space: nowrap; text-align: right">13.42 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.54%</td>
    <td style="white-space: nowrap; text-align: right">13.40 ms</td>
    <td style="white-space: nowrap; text-align: right">14.42 ms</td>
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
    <td style="white-space: nowrap;text-align: right">74.51</td>
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
    <td style="white-space: nowrap">16.32 MB</td>
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
    <td style="white-space: nowrap; text-align: right">372.47</td>
    <td style="white-space: nowrap; text-align: right">2.68 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.28%</td>
    <td style="white-space: nowrap; text-align: right">2.68 ms</td>
    <td style="white-space: nowrap; text-align: right">2.88 ms</td>
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
    <td style="white-space: nowrap;text-align: right">372.47</td>
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
    <td style="white-space: nowrap">3.12 MB</td>
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
    <td style="white-space: nowrap; text-align: right">3.60 K</td>
    <td style="white-space: nowrap; text-align: right">277.81 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.22%</td>
    <td style="white-space: nowrap; text-align: right">274.21 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">328.41 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">3.60 K</td>
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
    <td style="white-space: nowrap">331.26 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>