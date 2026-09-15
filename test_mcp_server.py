#!/usr/bin/env python3
"""Test script to connect to the Essential Viewer MCP server and inspect tools/resources."""

import asyncio
import sys

from mcp import ClientSession
from mcp.client.stdio import stdio_client, StdioServerParameters


async def main():
    # Start the Docker container with stdio transport
    print("=" * 70)
    print("Starting Essential Viewer MCP server via Docker...")
    print("=" * 70)

    server_params = StdioServerParameters(
        command="docker",
        args=["run", "-i", "--rm",
              "--name", "essential-view-builder-mcp",
              "eas/essential-view-builder-mcp:v1"],
    )

    try:
        async with stdio_client(server_params) as (read, write):
            async with ClientSession(read, write) as session:
                # Initialize
                print("\n[1] Initializing connection...\n")
                await session.initialize()
                print("  -> Connection initialized successfully!\n")

                # List tools
                print("=" * 70)
                print("[2] Listing available tools:")
                print("=" * 70 + "\n")
                tools_result = await session.list_tools()
                tools = tools_result.tools
                print(f"  Total tools found: {len(tools)}\n")
                for t in tools:
                    print(f"  Tool: {t.name}")
                    print(f"    Description: {t.description}")
                    print(f"    Input schema: {t.inputSchema}")
                    print()

                # List resources
                print("=" * 70)
                print("[3] Listing available resources:")
                print("=" * 70 + "\n")
                resources_result = await session.list_resources()
                resources = resources_result.resources
                print(f"  Total resources found: {len(resources)}\n")
                for r in resources:
                    print(f"  Resource: {r.name}")
                    print(f"    URI: {r.uri}")
                    print(f"    MIME type: {r.mimeType}")
                    print(f"    Description: {r.description}")
                    print()

                # Test reading a resource
                print("=" * 70)
                print("[4] Testing resource read: essential-view://api-docs")
                print("=" * 70 + "\n")
                try:
                    target_uri = "essential-view://api-docs"
                    found = any(str(r.uri) == target_uri for r in resources)
                    if found:
                        read_result = await session.read_resource(target_uri)
                        print(f"  Successfully read resource '{target_uri}'")
                        for content in read_result.contents:
                            text = content.text if hasattr(content, 'text') else str(content)
                            print(f"\n  Content (first 1500 chars):\n  {'-' * 50}")
                            print(f"  {text[:1500]}")
                            if len(text) > 1500:
                                print(f"  ... ({len(text)} chars total)")
                            print(f"  {'-' * 50}\n")
                    else:
                        available_uris = [r.uri for r in resources]
                        print(f"  Resource '{target_uri}' not found.")
                        print(f"  Available URIs: {available_uris}")
                        if available_uris:
                            print(f"\n  Trying first available resource: {available_uris[0]}")
                            read_result = await session.read_resource(available_uris[0])
                            for content in read_result.contents:
                                text = content.text if hasattr(content, 'text') else str(content)
                                print(f"\n  Content (first 1500 chars):\n  {'-' * 50}")
                                print(f"  {text[:1500]}")
                                if len(text) > 1500:
                                    print(f"  ... ({len(text)} chars total)")
                                print(f"  {'-' * 50}\n")
                except Exception as e:
                    print(f"  ERROR reading resource: {e}\n")

                # Test calling a tool
                print("=" * 70)
                print("[5] Testing tool call: suggest_view_architecture")
                print("=" * 70 + "\n")
                try:
                    tool_name = "suggest_view_architecture"
                    found_tool = next((t for t in tools if t.name == tool_name), None)
                    if found_tool:
                        args = {"view_description": "A simple todo list app with CRUD operations"}
                        call_result = await session.call_tool(tool_name, args)
                        print(f"  Called tool '{tool_name}' with args: {args}")
                        for content in call_result.content:
                            if hasattr(content, 'text'):
                                print(f"\n  Result:\n  {content.text}")
                            else:
                                print(f"\n  Result: {content}")
                        print()
                    else:
                        print(f"  Tool '{tool_name}' not found.")
                        tool_names = [t.name for t in tools]
                        print(f"  Available tools: {tool_names}")
                        if tool_names:
                            first_tool = tool_names[0]
                            print(f"\n  Trying first available tool: {first_tool}")
                            call_result = await session.call_tool(first_tool, {})
                            for content in call_result.content:
                                if hasattr(content, 'text'):
                                    print(f"\n  Result:\n  {content.text}")
                                else:
                                    print(f"\n  Result: {content}")
                            print()
                except Exception as e:
                    print(f"  ERROR calling tool: {e}\n")

                print("=" * 70)
                print("[SUMMARY]")
                print("=" * 70)
                print(f"  Tools available: {len(tools)}")
                for t in tools:
                    print(f"    - {t.name}")
                print(f"  Resources available: {len(resources)}")
                for r in resources:
                    print(f"    - {r.uri} ({r.name})")
                print("\n  Server is responding correctly!")
                print()

    except Exception as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
