import { useState, useEffect } from 'react';
import { HexColorPicker } from 'react-colorful';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { cn } from '@/lib/utils';

// Preset colors matching the system
const PRESET_COLORS = [
    { name: 'Green', hex: '#4ade80' },
    { name: 'Blue', hex: '#3b82f6' },
    { name: 'Purple', hex: '#a855f7' },
    { name: 'Red', hex: '#ef4444' },
    { name: 'Orange', hex: '#f97316' },
    { name: 'Pink', hex: '#ec4899' },
    { name: 'Teal', hex: '#14b8a6' },
    { name: 'Yellow', hex: '#eab308' },
];

// Converts HSL string to HEX
function hslToHex(hsl: string): string {
    const match = hsl.match(/hsl\((\d+)\s+(\d+)%\s+(\d+)%\)/);
    if (!match) return hsl.startsWith('#') ? hsl : '#4ade80';

    const h = parseInt(match[1]) / 360;
    const s = parseInt(match[2]) / 100;
    const l = parseInt(match[3]) / 100;

    const hue2rgb = (p: number, q: number, t: number) => {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    };

    let r, g, b;
    if (s === 0) {
        r = g = b = l;
    } else {
        const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        const p = 2 * l - q;
        r = hue2rgb(p, q, h + 1 / 3);
        g = hue2rgb(p, q, h);
        b = hue2rgb(p, q, h - 1 / 3);
    }

    const toHex = (x: number) => {
        const hex = Math.round(x * 255).toString(16);
        return hex.length === 1 ? '0' + hex : hex;
    };

    return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

// Converts HEX to HSL string
function hexToHsl(hex: string): string {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    if (!result) return hex;

    const r = parseInt(result[1], 16) / 255;
    const g = parseInt(result[2], 16) / 255;
    const b = parseInt(result[3], 16) / 255;

    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h = 0, s = 0;
    const l = (max + min) / 2;

    if (max !== min) {
        const d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        switch (max) {
            case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
            case g: h = ((b - r) / d + 2) / 6; break;
            case b: h = ((r - g) / d + 4) / 6; break;
        }
    }

    return `hsl(${Math.round(h * 360)} ${Math.round(s * 100)}% ${Math.round(l * 100)}%)`;
}

interface ColorPickerProps {
    value: string;
    onChange: (color: string) => void;
    className?: string;
    showValueLabel?: boolean;
}

export function ColorPicker({ value, onChange, className, showValueLabel = true }: ColorPickerProps) {
    const [hexValue, setHexValue] = useState(() => hslToHex(value));
    const [open, setOpen] = useState(false);

    useEffect(() => {
        setHexValue(hslToHex(value));
    }, [value]);

    const handleColorChange = (hex: string) => {
        setHexValue(hex);
        onChange(hexToHsl(hex));
    };

    const handlePresetClick = (hex: string) => {
        setHexValue(hex);
        onChange(hexToHsl(hex));
    };

    return (
        <Sheet open={open} onOpenChange={setOpen}>
            <SheetTrigger asChild>
                <Button
                    type="button"
                    variant="outline"
                    className={cn(
                        "w-full justify-start gap-3 h-10 rounded-xl bg-black/20 border-white/10 hover:bg-white/5",
                        !showValueLabel && "justify-center px-0 gap-0",
                        className
                    )}
                >
                    <div
                        className="h-5 w-5 rounded-full shadow-[0_0_10px_currentColor] shrink-0"
                        style={{ backgroundColor: hexValue, color: hexValue }}
                    />
                    {showValueLabel && <span className="font-mono text-sm uppercase tracking-wider">{hexValue}</span>}
                </Button>
            </SheetTrigger>
            <SheetContent side="bottom" className="bg-[#0a0a0a]/95 backdrop-blur-2xl border-white/10">
                <SheetHeader className="pb-4">
                    <SheetTitle>Seleziona Colore</SheetTitle>
                </SheetHeader>

                <div className="space-y-6 pb-6 max-w-md mx-auto">
                    {/* Color Wheel */}
                    <div className="flex justify-center">
                        <HexColorPicker
                            color={hexValue}
                            onChange={handleColorChange}
                            style={{ width: '100%', height: '180px' }}
                        />
                    </div>

                    {/* Hex Input */}
                    <div className="space-y-2">
                        <Label className="text-xs uppercase tracking-wider text-muted-foreground">
                            Codice HEX
                        </Label>
                        <div className="flex items-center gap-3">
                            <div
                                className="h-12 w-12 rounded-xl border border-white/10 shrink-0 shadow-[0_0_15px_currentColor]"
                                style={{ backgroundColor: hexValue, color: hexValue }}
                            />
                            <div className="flex-1 relative">
                                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground font-mono text-lg">#</span>
                                <Input
                                    value={hexValue.replace('#', '')}
                                    onChange={(e) => {
                                        const val = e.target.value.replace(/[^a-fA-F0-9]/g, '').slice(0, 6);
                                        if (val.length === 6) {
                                            handleColorChange('#' + val);
                                        } else {
                                            setHexValue('#' + val);
                                        }
                                    }}
                                    className="pl-10 font-mono uppercase bg-black/30 border-white/10 h-12 rounded-xl text-lg"
                                    maxLength={6}
                                    placeholder="4ade80"
                                />
                            </div>
                        </div>
                    </div>

                    {/* Preset Colors */}
                    <div className="space-y-2">
                        <Label className="text-xs uppercase tracking-wider text-muted-foreground">
                            Colori Rapidi
                        </Label>
                        <div className="grid grid-cols-8 gap-2">
                            {PRESET_COLORS.map((preset) => (
                                <button
                                    key={preset.hex}
                                    type="button"
                                    onClick={() => handlePresetClick(preset.hex)}
                                    className={cn(
                                        "aspect-square w-full rounded-xl border-2 transition-all hover:scale-110 shadow-[0_0_8px_currentColor]",
                                        hexValue.toLowerCase() === preset.hex.toLowerCase()
                                            ? "border-white scale-110"
                                            : "border-transparent"
                                    )}
                                    style={{ backgroundColor: preset.hex, color: preset.hex }}
                                    title={preset.name}
                                />
                            ))}
                        </div>
                    </div>

                    {/* Confirm Button */}
                    <Button
                        onClick={() => setOpen(false)}
                        className="w-full h-12 rounded-xl text-base"
                    >
                        Conferma Colore
                    </Button>
                </div>
            </SheetContent>
        </Sheet>
    );
}
