class_name TestCase
extends RefCounted
## Base dos testes. Cada arquivo tests/test_*.gd estende TestCase e tem funções test_*().

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s (esperado %s, veio %s)" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s (esperado %.3f ± %.3f, veio %.3f)" % [message, expected, tolerance, actual])
