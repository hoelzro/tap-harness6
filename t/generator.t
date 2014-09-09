use TAP::Parser;
use TAP::Entry;
use TAP::Generator;

my $source = TAP::Parser::Async::Source::Through.new();
my $parser = TAP::Parser::Async.new(:name("Self-Testing"), :$source);
my $elements = TAP::Collector.new();
my $g = TAP::Generator.new(:output(TAP::Entry::Handler::Multi.new(:handlers([$source, $elements]))));

$g.plan(3);
$g.test(:ok, :description("This tests passes"));

$g.start-subtest("subtest");
$g.test(:ok);
$g.plan(1);
$g.stop-subtest();

$g.test(:ok, :directive(TAP::Skip));

my $ret = $g.stop-tests();

await $parser.done;

my $h = TAP::Generator.new(:output(TAP::Output.new));

my $result = $parser.result;

$h.test(:ok($ret == 0), :description('Test would have returned 0'));
$h.test(:ok($result.tests-planned == 3), :description('Expected 3 test'));
$h.test(:ok($result.tests-run == 3), :description('Ran 3 test'));
$h.test(:ok($result.passed == 3), :description('Passed 3 tests'));
$h.test(:ok($result.failed == 0), :description('Failed 0 tests'));

my @expected = 
	TAP::Plan,
	TAP::Test,
	TAP::Sub-Entry[TAP::Comment],
	TAP::Sub-Entry[TAP::Test],
	TAP::Sub-Entry[TAP::Plan],
	TAP::Test,
	TAP::Test,
;

for @($elements.entries) Z @expected -> $got, $expected {
	my $ok = $got ~~ $expected;
	$h.test(:$ok, :description("Expected a " ~ $expected.WHAT.perl));
	if !$ok {
		$h.comment("Expected {$expected.WHAT.perl}, got a {$got.WHAT.perl}");
	}
}
$h.done-testing();
$h.stop-tests();

