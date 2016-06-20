function run_test(dir)
   os.execute('cd '..dir..' && ldoc --testing . && diff -r doc cdocs')
end
run_test('tests')
run_test('tests/example')
run_test('tests/md-test')
