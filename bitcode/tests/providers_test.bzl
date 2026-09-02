"""Analysis tests for source classification."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("//bitcode:providers.bzl", "is_compilable_source", "is_cxx_source")

def _fake(name):
    return struct(basename = name, extension = name.rsplit(".", 1)[-1])

def _test_cxx_detection(env):
    for n in ["a.cc", "a.cpp", "a.cxx", "a.C", "a.mm"]:
        env.expect.that_bool(is_cxx_source(_fake(n))).equals(True)
    for n in ["a.c", "a.m"]:
        env.expect.that_bool(is_cxx_source(_fake(n))).equals(False)

def _test_compilable_detection(env):
    for n in ["a.c", "a.cc", "a.cpp", "a.m", "a.mm"]:
        env.expect.that_bool(is_compilable_source(_fake(n))).equals(True)
    for n in ["a.h", "a.hpp", "a.inc", "a.td", "README.md"]:
        env.expect.that_bool(is_compilable_source(_fake(n))).equals(False)

def providers_test_suite(name):
    test_suite(name = name, basic_tests = [
        _test_cxx_detection,
        _test_compilable_detection,
    ])
