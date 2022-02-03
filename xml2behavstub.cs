/*

xml2behavstub <path> <name>

Converts RotMG XML data in <path> into BehaviorDb.<name>.cs behaviors.

The behaviors are empty and meant to be filled in with real behaviors.

There is useful data above each behavior, such as the DisplayId, projectiles,
whether it's invisible etc., so that you don't have to ctrl-F for this
information in the source data.

Compile this with Visual Studio or csc (Visual C# Command Line Compiler).
csc xml2behavstub.cs
If you don't have Visual Studio, you probably do have .NET - search
for csc in C:\Windows\Microsoft.NET\Framework\

Run it by drag-and-dropping your XML onto the executable and writing a name.
You can also run it from the command line.
xml2behavstub.exe parasiteDenObjects.xml ParasiteChambers

(c) twiswist 2022
Permission to use, copy, modify, and/or distribute this software for
any purpose with or without fee is hereby granted. This software is
offered as-is, without any warranty.

*/

using System; // Console
using System.IO; // File, Path
using System.Text; // StringBuilder
using System.Xml.Linq; // XElement
using System.Reflection; // Assembly
using System.Globalization; // NumberStyles

namespace xml2behavstub
{
	static class xml2behavstub
	{
		static StringBuilder sb = new StringBuilder();
		
		static int Main(string[] args)
		{
			string inpath = args.Length > 0 ? args[0] : Prompt("You should've drag-and-dropped the XML to this exe.\nPath to XML file?\n> ");
			if (!File.Exists(inpath))
			{
				Console.Error.WriteLine("File does not exist");
				return 1;
			}
			
			string name = args.Length > 1 ? args[1] : Prompt("BehaviorDb.[Name].cs?\n> ");
			string filename = $"BehaviorDb.{name}.cs";
			string outpath = Path.Combine(Path.GetDirectoryName(Assembly.GetEntryAssembly().Location), filename);
			
			sb.AppendLine(@"using wServer.logic.behaviors;
using wServer.logic.loot;
using wServer.logic.transitions;

namespace wServer.logic
{
    partial class BehaviorDb
    {
        private _ " + name + @" = () => Behav()
");
			
			using (Stream stream = File.OpenRead(inpath))
			{
				XElement root = XElement.Load(stream);
				foreach (XElement elem in root.Elements())
				{
					DescribeObject(elem);
				}
			}
			
			sb.AppendLine(@";

    }
}");
			
			File.WriteAllText(outpath, sb.ToString());
			
			Console.Error.WriteLine($"Successfully created {filename}");
			
			return 0;
		}
		
		static void DescribeObject(XElement elem)
		{
			string @class = elem.Element("Class").Value;
			if (!(@class == "Character" || @class == "GameObject"))
				return;
			
			string id = elem.Attribute("id").Value;
			string displayId = elem.Element("DisplayId")?.Value;
			string group = elem.Element("Group")?.Value;
			
			if (group != null) sb.AppendLine("// Group: " + group);
			
			foreach (XElement child in elem.Elements("Projectile"))
				DescribeProjectile(child);
			
			foreach (XElement child in elem.Elements("Sound"))
				DescribeSound(child);
			
			foreach (XElement child in elem.Elements("AltTexture"))
				DescribeAltTexture(child);
			
			foreach (XElement child in elem.Elements("Effect"))
				DescribeEffect(child);
			
			if (TextureDataIsInvisible(elem))
				sb.AppendLine("// Invisible");
			
			if (displayId != null)
				sb.AppendLine("// DisplayId: " + displayId);
			
			sb.AppendLine($@".Init(""{id}"", new State(
    // behaviors
)
    // , loot
)
");
		}
		
		static void DescribeProjectile(XElement elem)
		{
			string id = elem.Attribute("id").Value;
			string objectId = elem.Element("ObjectId").Value;
			string damage = elem.Element("Damage").Value; // BUG: projectiles can have a damage range
			sb.AppendLine($"// Projectile {id}: {damage} damage {objectId}");
		}
		
		static void DescribeSound(XElement elem)
		{
			string id = elem.Attribute("id").Value;
			string sound = elem.Value;
			sb.AppendLine($"// Sound {id}: {sound}");
		}
		
		static void DescribeAltTexture(XElement elem)
		{
			// todo: describe texture data
			string id = elem.Attribute("id").Value;
			if (TextureDataIsInvisible(elem))
				sb.AppendLine($"// AltTexture {id}: invisible");
			else
				sb.AppendLine($"// AltTexture {id}");
		}
		
		static void DescribeEffect(XElement elem)
		{
			sb.AppendLine($"// {elem}");
		}
		
		static bool TextureDataIsInvisible(XElement elem)
		{
			XElement elemTemp;
			
			if ((elemTemp = elem.Element("Size")) != null)
			{
				int size = int.Parse(elemTemp.Value, NumberStyles.AllowLeadingSign);
				if (size <= 0)
					return true;
			}
			
			if ((elemTemp = elem.Element("Texture")) != null)
			{
				if (elemTemp.Element("File").Value == "invisible")
					return true;
			}
			
			return false;
		}
		
		// static ushort ParseId(string id)
		// {
			// if (id.StartsWith("0x")) id = id.Substring(2);
			// return ushort.Parse(id, NumberStyles.HexNumber);
		// }
		
		static string Prompt(string prompt)
		{
			// cheers to nekoT
			Console.Error.Write(prompt);
			return Console.ReadLine();
		}
	}
}
