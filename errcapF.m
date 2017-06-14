function [activity]=errcapF(raw)
    activity= min(raw, 1);
    activity = max(activity, 0);
end
    