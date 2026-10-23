import json
import unittest
from dev_codex import normalize_output, validate_request, output_schema, PROVIDER

TOOLS = [{'type': 'function', 'function': {'name': 'editor_file_read', 'parameters': {'type': 'object'}}}]


class CodexTests(unittest.TestCase):
    def test_only_advertised_browser_tools_become_calls(self):
        value = {'text': 'Inspecting', 'toolCalls': [{'name': 'editor_file_read', 'arguments': '{"path":"Sources/Game.ada"}'}]}
        text, calls = normalize_output(json.dumps(value), TOOLS)
        self.assertEqual(text, 'Inspecting')
        self.assertEqual(calls[0]['function'], value['toolCalls'][0])
        self.assertTrue(calls[0]['id'].startswith('codex_'))
        value['toolCalls'][0]['name'] = 'exec_command'
        with self.assertRaises(RuntimeError): normalize_output(json.dumps(value), TOOLS)
        value['toolCalls'][0] = {'name': 'editor_file_read', 'arguments': '[]'}
        with self.assertRaises(RuntimeError): normalize_output(json.dumps(value), TOOLS)

    def test_model_mode_and_operation_are_validated(self):
        body = {'providerID': PROVIDER, 'billingMode': 'codex', 'model': 'listed', 'mode': 'plan',
                'operationID': '00000000-0000-4000-8000-000000000001', 'messages': [{'role': 'user', 'content': 'Inspect'}], 'tools': TOOLS}
        validate_request(body, {'listed'})
        for change in [{'billingMode': 'byok'}, {'model': 'invented'}, {'mode': 'other'}, {'operationID': 'bad'}]:
            with self.assertRaises(ValueError): validate_request(dict(body, **change), {'listed'})
        schema = output_schema(['editor_file_read'])
        self.assertFalse(schema['additionalProperties'])
        self.assertEqual(schema['properties']['toolCalls']['items']['properties']['name']['enum'], ['editor_file_read'])
