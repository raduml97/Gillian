let test_suites : unit Alcotest.test list =
  [ ("Gil_syntax.Reducers", Gil_syntax_tests.Visitors.tests) ]

let () = Alcotest.run "Gillian" test_suites
